package main

import (
	"context"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
	"time"
)

type roundTripFunc func(*http.Request) (*http.Response, error)

func (f roundTripFunc) RoundTrip(request *http.Request) (*http.Response, error) {
	return f(request)
}

func TestDiscoverProxySSLHosts(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = io.WriteString(w, `[
          {"status":"online","technologies":[{"identifier":"proxy_ssl","metadata":[{"name":"proxy_hostname","value":"nl2.proxy.nordvpn.com"}],"pivot":{"status":"online"}}]},
          {"status":"online","technologies":[{"identifier":"proxy_ssl","metadata":[{"name":"proxy_hostname","value":"nl1.proxy.nordvpn.com"}],"pivot":{"status":"online"}}]},
          {"status":"offline","technologies":[{"identifier":"proxy_ssl","metadata":[{"name":"proxy_hostname","value":"offline.proxy.nordvpn.com"}],"pivot":{"status":"online"}}]}
        ]`)
	}))
	defer server.Close()

	hosts, err := discover(context.Background(), server.Client(), server.URL)
	if err != nil {
		t.Fatalf("discover: %v", err)
	}
	want := []string{"nl1.proxy.nordvpn.com", "nl2.proxy.nordvpn.com"}
	if strings.Join(hosts, ",") != strings.Join(want, ",") {
		t.Fatalf("hosts = %v, want %v", hosts, want)
	}
}

func TestHandlerRotatesOnRateLimitAndForcesPublicAuth(t *testing.T) {
	fixedNow := time.Unix(1_700_000_000, 0)
	var firstBody string
	first := &endpoint{host: "first", exitIP: "192.0.2.1", transport: roundTripFunc(func(request *http.Request) (*http.Response, error) {
		data, _ := io.ReadAll(request.Body)
		firstBody = string(data)
		return response(http.StatusTooManyRequests, "limited", http.Header{"Retry-After": []string{"30"}}), nil
	})}
	second := &endpoint{host: "second", exitIP: "192.0.2.2", transport: roundTripFunc(func(request *http.Request) (*http.Response, error) {
		data, _ := io.ReadAll(request.Body)
		if string(data) != firstBody {
			t.Fatalf("replayed body = %q, want %q", data, firstBody)
		}
		if got := request.Header.Get("Authorization"); got != "Bearer public" {
			t.Fatalf("Authorization = %q", got)
		}
		if request.Close || request.Header.Get("Connection") != "" || request.Header.Get("X-Internal") != "" {
			t.Fatalf("outbound request disables persistence or retains hop headers: close=%v headers=%v", request.Close, request.Header)
		}
		return response(http.StatusOK, "streamed", http.Header{"Content-Type": []string{"text/event-stream"}}), nil
	})}

	h := testHandler(fixedNow, first, second)
	request := httptest.NewRequest(http.MethodPost, "https://proxy.test/zen/v1/chat/completions", strings.NewReader(`{"model":"test"}`))
	request.Header.Set("Authorization", "Bearer secret-client-key")
	request.Header.Set("Connection", "close, X-Internal")
	request.Header.Set("X-Internal", "remove me")
	request.Close = true
	recorder := httptest.NewRecorder()
	h.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK || recorder.Body.String() != "streamed" {
		t.Fatalf("response = %d %q", recorder.Code, recorder.Body.String())
	}
	if first.available(fixedNow.Add(29 * time.Second)) {
		t.Fatal("rate-limited proxy remained available during cooldown")
	}
	if !first.available(fixedNow.Add(31 * time.Second)) {
		t.Fatal("rate-limited proxy did not recover after cooldown")
	}
}

func TestRemoveHopHeadersRemovesConnectionTokens(t *testing.T) {
	header := http.Header{
		"Connection": []string{"keep-alive, X-Internal"},
		"X-Internal": []string{"remove me"},
		"X-Keep":     []string{"keep me"},
	}
	removeHopHeaders(header)
	if header.Get("Connection") != "" || header.Get("X-Internal") != "" {
		t.Fatalf("hop headers remained: %v", header)
	}
	if header.Get("X-Keep") != "keep me" {
		t.Fatal("end-to-end header was removed")
	}
}

func TestHealthCheckDoesNotAdvanceRoundRobin(t *testing.T) {
	fixedNow := time.Unix(1_700_000_000, 0)
	pool := &proxyPool{endpoints: []*endpoint{
		{host: "first", exitIP: "192.0.2.1"},
		{host: "second", exitIP: "192.0.2.2"},
	}}
	h := testHandler(fixedNow)
	h.pool = pool

	recorder := httptest.NewRecorder()
	h.ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, "https://proxy.test/healthz", nil))
	if recorder.Code != http.StatusNoContent {
		t.Fatalf("health status = %d", recorder.Code)
	}
	if pool.next.Load() != 0 {
		t.Fatal("health check advanced round-robin selection")
	}
}

func TestHandlerRotatesOnTransportFailure(t *testing.T) {
	fixedNow := time.Unix(1_700_000_000, 0)
	first := &endpoint{host: "first", exitIP: "192.0.2.1", transport: roundTripFunc(func(*http.Request) (*http.Response, error) {
		return nil, errors.New("proxy unavailable")
	})}
	second := &endpoint{host: "second", exitIP: "192.0.2.2", transport: roundTripFunc(func(*http.Request) (*http.Response, error) {
		return response(http.StatusOK, "ok", nil), nil
	})}

	recorder := httptest.NewRecorder()
	testHandler(fixedNow, first, second).ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, "https://proxy.test/zen/v1/models", nil))
	if recorder.Code != http.StatusOK || recorder.Body.String() != "ok" {
		t.Fatalf("response = %d %q", recorder.Code, recorder.Body.String())
	}
	if first.available(fixedNow.Add(30 * time.Second)) {
		t.Fatal("failed proxy remained available during cooldown")
	}
}

func TestHandlerReturnsLastRateLimit(t *testing.T) {
	fixedNow := time.Unix(1_700_000_000, 0)
	first := &endpoint{host: "first", exitIP: "192.0.2.1", transport: roundTripFunc(func(*http.Request) (*http.Response, error) {
		return response(http.StatusTooManyRequests, "first", nil), nil
	})}
	second := &endpoint{host: "second", exitIP: "192.0.2.2", transport: roundTripFunc(func(*http.Request) (*http.Response, error) {
		return response(http.StatusTooManyRequests, "second", http.Header{"X-Rate-Limit": []string{"yes"}}), nil
	})}

	recorder := httptest.NewRecorder()
	testHandler(fixedNow, first, second).ServeHTTP(recorder, httptest.NewRequest(http.MethodPost, "https://proxy.test/zen/v1/responses", nil))
	if recorder.Code != http.StatusTooManyRequests || recorder.Body.String() != "second" {
		t.Fatalf("response = %d %q", recorder.Code, recorder.Body.String())
	}
	if recorder.Header().Get("X-Rate-Limit") != "yes" {
		t.Fatal("last rate-limit headers were not preserved")
	}
}

func TestPoolRetainsSessionByExitIP(t *testing.T) {
	originalTransport := roundTripFunc(func(*http.Request) (*http.Response, error) { return nil, nil })
	original := &endpoint{host: "first", serverIP: "192.0.2.10", exitIP: "198.51.100.1", transport: originalTransport}
	pool := &proxyPool{endpoints: []*endpoint{original}}
	replacement := &endpoint{
		host:      "second",
		serverIP:  "192.0.2.20",
		exitIP:    "198.51.100.1",
		transport: roundTripFunc(func(*http.Request) (*http.Response, error) { return nil, nil }),
	}

	pool.replace([]*endpoint{replacement})
	if len(pool.endpoints) != 1 || pool.endpoints[0] != original {
		t.Fatal("pool replaced the persistent transport for an unchanged exit IP")
	}
}

func TestPreferredIPPinsIPv4(t *testing.T) {
	if got := preferredIP([]string{"192.0.2.2", "2001:db8::1", "192.0.2.1"}); got != "192.0.2.1" {
		t.Fatalf("preferredIP = %q", got)
	}
}

func testHandler(now time.Time, endpoints ...*endpoint) *handler {
	upstream, _ := url.Parse("https://opencode.ai")
	return &handler{
		pool:              &proxyPool{endpoints: endpoints},
		upstream:          upstream,
		now:               func() time.Time { return now },
		failureCooldown:   time.Minute,
		rateLimitCooldown: 5 * time.Minute,
		bodyLimit:         1024,
	}
}

func response(status int, body string, header http.Header) *http.Response {
	if header == nil {
		header = make(http.Header)
	}
	return &http.Response{
		StatusCode: status,
		Header:     header,
		Body:       io.NopCloser(strings.NewReader(body)),
	}
}
