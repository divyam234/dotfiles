package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net"
	"net/http"
	"net/url"
	"os"
	"os/signal"
	"sort"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"time"
)

const (
	defaultListenAddr        = ":39174"
	defaultUpstreamURL       = "https://opencode.ai"
	defaultDiscoveryURL      = "https://api.nordvpn.com/v1/servers/recommendations?filters%5Bservers_technologies%5D%5Bidentifier%5D=proxy_ssl&limit=100"
	defaultProxyPort         = "89"
	defaultDiscoveryInterval = 15 * time.Minute
	defaultFailureCooldown   = time.Minute
	defaultRateLimitCooldown = 5 * time.Minute
	defaultBodyLimit         = 64 << 20
	proxyValidationWorkers   = 10
)

type endpoint struct {
	host      string
	serverIP  string
	exitIP    string
	transport http.RoundTripper
	mu        sync.Mutex
	until     time.Time
}

func (e *endpoint) available(now time.Time) bool {
	e.mu.Lock()
	defer e.mu.Unlock()
	return !now.Before(e.until)
}

func (e *endpoint) coolDown(until time.Time) {
	e.mu.Lock()
	defer e.mu.Unlock()
	if until.After(e.until) {
		e.until = until
	}
}

type proxyPool struct {
	mu        sync.RWMutex
	endpoints []*endpoint
	next      atomic.Uint64
}

func (p *proxyPool) replace(candidates []*endpoint) {
	p.mu.Lock()
	defer p.mu.Unlock()

	existing := make(map[string]*endpoint, len(p.endpoints))
	for _, candidate := range p.endpoints {
		existing[candidate.exitIP] = candidate
	}

	next := make([]*endpoint, 0, len(candidates))
	retained := make(map[string]struct{}, len(candidates))
	for _, candidate := range candidates {
		if current := existing[candidate.exitIP]; current != nil {
			closeIdleConnections(candidate.transport)
			candidate = current
		}
		next = append(next, candidate)
		retained[candidate.exitIP] = struct{}{}
	}
	for _, candidate := range p.endpoints {
		if _, ok := retained[candidate.exitIP]; !ok {
			closeIdleConnections(candidate.transport)
		}
	}
	p.endpoints = next
}

func (p *proxyPool) candidates(now time.Time) []*endpoint {
	p.mu.RLock()
	defer p.mu.RUnlock()

	available := make([]*endpoint, 0, len(p.endpoints))
	for _, candidate := range p.endpoints {
		if candidate.available(now) {
			available = append(available, candidate)
		}
	}
	if len(available) < 2 {
		return available
	}

	start := int(p.next.Add(1)-1) % len(available)
	ordered := make([]*endpoint, 0, len(available))
	ordered = append(ordered, available[start:]...)
	ordered = append(ordered, available[:start]...)
	return ordered
}

func (p *proxyPool) hasAvailable(now time.Time) bool {
	p.mu.RLock()
	defer p.mu.RUnlock()
	for _, candidate := range p.endpoints {
		if candidate.available(now) {
			return true
		}
	}
	return false
}

type handler struct {
	pool              *proxyPool
	upstream          *url.URL
	now               func() time.Time
	failureCooldown   time.Duration
	rateLimitCooldown time.Duration
	bodyLimit         int64
}

type savedResponse struct {
	status int
	header http.Header
	body   []byte
}

func (h *handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path == "/healthz" {
		if !h.pool.hasAvailable(h.now()) {
			http.Error(w, "no healthy proxies", http.StatusServiceUnavailable)
			return
		}
		w.WriteHeader(http.StatusNoContent)
		return
	}

	body, err := readRequestBody(r.Body, h.bodyLimit)
	if err != nil {
		http.Error(w, err.Error(), http.StatusRequestEntityTooLarge)
		return
	}

	candidates := h.pool.candidates(h.now())
	if len(candidates) == 0 {
		http.Error(w, "no healthy Nord proxies", http.StatusServiceUnavailable)
		return
	}

	var lastRateLimit *savedResponse
	var lastErr error
	for _, candidate := range candidates {
		out := r.Clone(r.Context())
		out.RequestURI = ""
		out.URL = cloneURL(r.URL)
		out.URL.Scheme = h.upstream.Scheme
		out.URL.Host = h.upstream.Host
		out.Host = h.upstream.Host
		out.Body = io.NopCloser(bytes.NewReader(body))
		out.ContentLength = int64(len(body))
		out.Close = false
		out.TransferEncoding = nil
		out.Trailer = nil
		out.Header = r.Header.Clone()
		removeHopHeaders(out.Header)
		out.Header.Set("Authorization", "Bearer public")

		response, err := candidate.transport.RoundTrip(out)
		if err != nil {
			lastErr = err
			candidate.coolDown(h.now().Add(h.failureCooldown))
			slog.Warn("Nord proxy request failed", "exit_ip", candidate.exitIP, "error", err)
			continue
		}

		if response.StatusCode == http.StatusTooManyRequests {
			saved, saveErr := saveResponse(response)
			if saveErr != nil {
				lastErr = saveErr
				continue
			}
			lastRateLimit = saved
			cooldown := retryAfter(response.Header.Get("Retry-After"), h.now(), h.rateLimitCooldown)
			candidate.coolDown(h.now().Add(cooldown))
			slog.Info("Nord proxy egress rate limited", "exit_ip", candidate.exitIP, "cooldown", cooldown)
			continue
		}

		writeResponse(w, response)
		return
	}

	if lastRateLimit != nil {
		copyHeaders(w.Header(), lastRateLimit.header)
		w.WriteHeader(lastRateLimit.status)
		_, _ = w.Write(lastRateLimit.body)
		return
	}
	if lastErr != nil {
		slog.Error("all Nord proxies failed", "error", lastErr)
	}
	http.Error(w, "all Nord proxies failed", http.StatusBadGateway)
}

func readRequestBody(body io.ReadCloser, limit int64) ([]byte, error) {
	if body == nil {
		return nil, nil
	}
	defer body.Close()
	limited := io.LimitReader(body, limit+1)
	data, err := io.ReadAll(limited)
	if err != nil {
		return nil, fmt.Errorf("read request body: %w", err)
	}
	if int64(len(data)) > limit {
		return nil, fmt.Errorf("request body exceeds %d bytes", limit)
	}
	return data, nil
}

func cloneURL(source *url.URL) *url.URL {
	clone := *source
	return &clone
}

func saveResponse(response *http.Response) (*savedResponse, error) {
	defer response.Body.Close()
	body, err := io.ReadAll(response.Body)
	if err != nil {
		return nil, fmt.Errorf("read rate-limit response: %w", err)
	}
	header := response.Header.Clone()
	removeHopHeaders(header)
	return &savedResponse{status: response.StatusCode, header: header, body: body}, nil
}

func writeResponse(w http.ResponseWriter, response *http.Response) {
	defer response.Body.Close()
	removeHopHeaders(response.Header)
	copyHeaders(w.Header(), response.Header)
	w.WriteHeader(response.StatusCode)

	buffer := make([]byte, 32*1024)
	for {
		count, readErr := response.Body.Read(buffer)
		if count > 0 {
			if _, writeErr := w.Write(buffer[:count]); writeErr != nil {
				return
			}
			if flusher, ok := w.(http.Flusher); ok {
				flusher.Flush()
			}
		}
		if readErr != nil {
			return
		}
	}
}

func copyHeaders(destination, source http.Header) {
	for key, values := range source {
		for _, value := range values {
			destination.Add(key, value)
		}
	}
}

func removeHopHeaders(header http.Header) {
	for _, connection := range header.Values("Connection") {
		for token := range strings.SplitSeq(connection, ",") {
			header.Del(strings.TrimSpace(token))
		}
	}
	for _, key := range []string{
		"Connection",
		"Proxy-Connection",
		"Keep-Alive",
		"Proxy-Authenticate",
		"Proxy-Authorization",
		"Te",
		"Trailer",
		"Transfer-Encoding",
		"Upgrade",
	} {
		header.Del(key)
	}
}

func retryAfter(value string, now time.Time, fallback time.Duration) time.Duration {
	if seconds, err := strconv.Atoi(strings.TrimSpace(value)); err == nil && seconds > 0 {
		return time.Duration(seconds) * time.Second
	}
	if deadline, err := http.ParseTime(value); err == nil && deadline.After(now) {
		return deadline.Sub(now)
	}
	return fallback
}

type nordServer struct {
	Status       string `json:"status"`
	Technologies []struct {
		Identifier string `json:"identifier"`
		Metadata   []struct {
			Name  string `json:"name"`
			Value string `json:"value"`
		} `json:"metadata"`
		Pivot struct {
			Status string `json:"status"`
		} `json:"pivot"`
	} `json:"technologies"`
}

func discover(ctx context.Context, client *http.Client, discoveryURL string) ([]string, error) {
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, discoveryURL, nil)
	if err != nil {
		return nil, fmt.Errorf("create Nord discovery request: %w", err)
	}
	response, err := client.Do(request)
	if err != nil {
		return nil, fmt.Errorf("fetch Nord proxies: %w", err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("fetch Nord proxies: unexpected status %s", response.Status)
	}

	var servers []nordServer
	if err := json.NewDecoder(response.Body).Decode(&servers); err != nil {
		return nil, fmt.Errorf("decode Nord proxies: %w", err)
	}

	unique := make(map[string]struct{})
	for _, server := range servers {
		if server.Status != "online" {
			continue
		}
		for _, technology := range server.Technologies {
			if technology.Identifier != "proxy_ssl" || technology.Pivot.Status != "online" {
				continue
			}
			for _, metadata := range technology.Metadata {
				if metadata.Name == "proxy_hostname" && metadata.Value != "" {
					unique[metadata.Value] = struct{}{}
				}
			}
		}
	}

	hosts := make([]string, 0, len(unique))
	for host := range unique {
		hosts = append(hosts, host)
	}
	sort.Strings(hosts)
	if len(hosts) == 0 {
		return nil, errors.New("Nord discovery returned no online HTTPS proxies")
	}
	return hosts, nil
}

func newProxyTransport(host, serverIP, port, username, password string) http.RoundTripper {
	proxyURL := &url.URL{
		Scheme: "https",
		Host:   host + ":" + port,
		User:   url.UserPassword(username, password),
	}
	dialer := &net.Dialer{Timeout: 10 * time.Second, KeepAlive: 30 * time.Second}
	return &http.Transport{
		Proxy: http.ProxyURL(proxyURL),
		DialContext: func(ctx context.Context, network, address string) (net.Conn, error) {
			addressHost, addressPort, err := net.SplitHostPort(address)
			if err != nil {
				return nil, err
			}
			if addressHost == host {
				address = net.JoinHostPort(serverIP, addressPort)
			}
			return dialer.DialContext(ctx, network, address)
		},
		ForceAttemptHTTP2:     true,
		MaxIdleConns:          8,
		MaxIdleConnsPerHost:   8,
		MaxConnsPerHost:       8,
		IdleConnTimeout:       90 * time.Second,
		TLSHandshakeTimeout:   10 * time.Second,
		ResponseHeaderTimeout: 2 * time.Minute,
	}
}

func prepareEndpoints(
	ctx context.Context,
	hosts []string,
	port string,
	username string,
	password string,
) ([]*endpoint, error) {
	type result struct {
		endpoint *endpoint
		err      error
	}
	results := make(chan result, len(hosts))
	workers := make(chan struct{}, proxyValidationWorkers)
	for _, host := range hosts {
		go func() {
			workers <- struct{}{}
			defer func() { <-workers }()
			candidate, err := prepareEndpoint(ctx, net.DefaultResolver, host, port, username, password)
			results <- result{endpoint: candidate, err: err}
		}()
	}

	byExitIP := make(map[string]*endpoint)
	for range hosts {
		result := <-results
		if result.err != nil {
			slog.Warn("Nord proxy validation failed", "error", result.err)
			continue
		}
		if duplicate := byExitIP[result.endpoint.exitIP]; duplicate != nil {
			if endpointAddress(duplicate) < endpointAddress(result.endpoint) {
				closeIdleConnections(result.endpoint.transport)
				continue
			}
			closeIdleConnections(duplicate.transport)
		}
		byExitIP[result.endpoint.exitIP] = result.endpoint
	}

	endpoints := make([]*endpoint, 0, len(byExitIP))
	for _, candidate := range byExitIP {
		endpoints = append(endpoints, candidate)
	}
	sort.Slice(endpoints, func(i, j int) bool { return endpoints[i].exitIP < endpoints[j].exitIP })
	if len(endpoints) == 0 {
		return nil, errors.New("no Nord HTTPS proxies passed egress validation")
	}
	return endpoints, nil
}

func endpointAddress(candidate *endpoint) string {
	return candidate.host + "\x00" + candidate.serverIP
}

func prepareEndpoint(
	ctx context.Context,
	resolver *net.Resolver,
	host string,
	port string,
	username string,
	password string,
) (*endpoint, error) {
	addresses, err := resolver.LookupHost(ctx, host)
	if err != nil {
		return nil, fmt.Errorf("resolve %s: %w", host, err)
	}
	serverIP := preferredIP(addresses)
	if serverIP == "" {
		return nil, fmt.Errorf("resolve %s: no IP addresses", host)
	}

	transport := newProxyTransport(host, serverIP, port, username, password)
	probeCtx, cancel := context.WithTimeout(ctx, 15*time.Second)
	defer cancel()
	request, err := http.NewRequestWithContext(probeCtx, http.MethodGet, "https://api.ipify.org", nil)
	if err != nil {
		return nil, err
	}
	response, err := transport.RoundTrip(request)
	if err != nil {
		closeIdleConnections(transport)
		return nil, fmt.Errorf("probe %s via %s: %w", host, serverIP, err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		closeIdleConnections(transport)
		return nil, fmt.Errorf("probe %s via %s: unexpected status %s", host, serverIP, response.Status)
	}
	body, err := io.ReadAll(io.LimitReader(response.Body, 128))
	if err != nil {
		closeIdleConnections(transport)
		return nil, fmt.Errorf("read egress IP for %s: %w", host, err)
	}
	exitIP := strings.TrimSpace(string(body))
	if net.ParseIP(exitIP) == nil {
		closeIdleConnections(transport)
		return nil, fmt.Errorf("probe %s returned invalid egress IP %q", host, exitIP)
	}
	return &endpoint{
		host:      host,
		serverIP:  serverIP,
		exitIP:    exitIP,
		transport: transport,
	}, nil
}

func preferredIP(addresses []string) string {
	addresses = append([]string(nil), addresses...)
	sort.Strings(addresses)
	for _, address := range addresses {
		if parsed := net.ParseIP(address); parsed != nil && parsed.To4() != nil {
			return address
		}
	}
	if len(addresses) > 0 && net.ParseIP(addresses[0]) != nil {
		return addresses[0]
	}
	return ""
}

func closeIdleConnections(transport http.RoundTripper) {
	if closer, ok := transport.(interface{ CloseIdleConnections() }); ok {
		closer.CloseIdleConnections()
	}
}

func main() {
	username := os.Getenv("NORDVPN_SERVICE_USERNAME")
	password := os.Getenv("NORDVPN_SERVICE_PASSWORD")
	if username == "" || password == "" {
		slog.Error("NORDVPN_SERVICE_USERNAME and NORDVPN_SERVICE_PASSWORD are required")
		os.Exit(1)
	}

	upstream, err := url.Parse(envOr("ZENPROXY_UPSTREAM_URL", defaultUpstreamURL))
	if err != nil {
		slog.Error("invalid upstream URL", "error", err)
		os.Exit(1)
	}

	discoveryURL := envOr("ZENPROXY_DISCOVERY_URL", defaultDiscoveryURL)
	discoveryClient := &http.Client{Timeout: 15 * time.Second}
	pool := &proxyPool{}
	refresh := func(ctx context.Context) error {
		hosts, err := discover(ctx, discoveryClient, discoveryURL)
		if err != nil {
			return err
		}
		endpoints, err := prepareEndpoints(
			ctx,
			hosts,
			envOr("ZENPROXY_PROXY_PORT", defaultProxyPort),
			username,
			password,
		)
		if err != nil {
			return err
		}
		pool.replace(endpoints)
		slog.Info("refreshed Nord HTTPS proxies", "hosts", len(hosts), "unique_exit_ips", len(endpoints))
		return nil
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	if err := refresh(ctx); err != nil {
		slog.Error("initial Nord proxy discovery failed", "error", err)
		os.Exit(1)
	}

	go func() {
		ticker := time.NewTicker(defaultDiscoveryInterval)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				if err := refresh(ctx); err != nil {
					slog.Warn("Nord proxy refresh failed; retaining current pool", "error", err)
				}
			}
		}
	}()

	server := &http.Server{
		Addr: envOr("ZENPROXY_LISTEN_ADDR", defaultListenAddr),
		Handler: &handler{
			pool:              pool,
			upstream:          upstream,
			now:               time.Now,
			failureCooldown:   defaultFailureCooldown,
			rateLimitCooldown: defaultRateLimitCooldown,
			bodyLimit:         defaultBodyLimit,
		},
		ReadHeaderTimeout: 10 * time.Second,
		IdleTimeout:       2 * time.Minute,
	}

	go func() {
		<-ctx.Done()
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()
		if err := server.Shutdown(shutdownCtx); err != nil {
			slog.Error("server shutdown failed", "error", err)
		}
	}()

	slog.Info("zenproxy listening", "address", server.Addr)
	if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		slog.Error("zenproxy server failed", "error", err)
		os.Exit(1)
	}
}

func envOr(name, fallback string) string {
	if value := os.Getenv(name); value != "" {
		return value
	}
	return fallback
}
