package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"net/url"
	"strings"
	"time"
)

const (
	cmdSessionsCreate  = "sessions.create"
	cmdSessionsList    = "sessions.list"
	cmdSessionsDestroy = "sessions.destroy"
	cmdRequestGet      = "request.get"
	cmdRequestPost     = "request.post"

	defaultMaxTimeout = int64(60000)
	pollInterval      = 2 * time.Second
	maxBodyBytes      = 1 << 20
)

// flareCookie mirrors the FlareSolverr cookie object. Inbound cookies may
// omit domain/path; outbound cookies are synthesized from document.cookie
// plus the final page URL, so only name, value, domain, path, secure and
// httpOnly are ever populated.
type flareCookie struct {
	Name     string `json:"name"`
	Value    string `json:"value"`
	Domain   string `json:"domain,omitempty"`
	Path     string `json:"path,omitempty"`
	Expires  *int64 `json:"expires,omitempty"`
	HTTPOnly bool   `json:"httpOnly,omitempty"`
	Secure   bool   `json:"secure,omitempty"`
}

// flareRequest mirrors the FlareSolverr POST /v1 body. The proxy knob is
// accepted for compatibility but ignored: Camofox routing is server-global
// configuration, not a per-request parameter.
type flareRequest struct {
	Cmd               string        `json:"cmd"`
	URL               string        `json:"url"`
	Session           string        `json:"session"`
	SessionTTLMinutes *int          `json:"session_ttl_minutes"`
	MaxTimeout        int64         `json:"maxTimeout"`
	Cookies           []flareCookie `json:"cookies"`
	PostData          *string       `json:"postData"`
	// Accepted for compatibility; solutions are always cookies-only.
	ReturnOnlyCookies bool `json:"returnOnlyCookies"`
	// Rejected: rendering is client-side, camoflare mints cookies only.
	ReturnScreenshot bool `json:"returnScreenshot"`
	WaitInSeconds     *int          `json:"waitInSeconds"`
}

type flareSolution struct {
	// camoflare is a cookie minter: clients handle rendering, headers
	// and screenshots themselves, so the solution carries only what
	// cookie replay needs.
	URL       string        `json:"url"`
	Cookies   []flareCookie `json:"cookies"`
	UserAgent string        `json:"userAgent"`
}

type flareResponse struct {
	Solution       *flareSolution `json:"solution,omitempty"`
	Status         string         `json:"status"`
	Message        string         `json:"message"`
	Session        string         `json:"session,omitempty"`
	Sessions       []string       `json:"sessions,omitempty"`
	StartTimestamp int64          `json:"startTimestamp"`
	EndTimestamp   int64          `json:"endTimestamp"`
	Version        string         `json:"version"`
}

type server struct {
	cfg    config
	client browserAPI
	store  *sessionStore
	logger *slog.Logger
}

func newServer(cfg config, client browserAPI, logger *slog.Logger) *server {
	s := &server{cfg: cfg, client: client, logger: logger}
	if client != nil {
		if c, ok := client.(interface {
			destroySession(ctx context.Context, userID string) error
		}); ok {
			destroy := c.destroySession
			s.store = newSessionStore(func(ctx context.Context, userID string) {
				_ = destroy(ctx, userID)
			})
		}
	}
	if s.store == nil {
		s.store = newSessionStore(func(context.Context, string) {})
	}
	go s.store.startSweeper(context.Background(), time.Minute)
	return s
}

func (s *server) routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("POST /v1", s.handleV1)
	mux.HandleFunc("GET /health", s.handleHealth)
	return mux
}

func (s *server) handleHealth(w http.ResponseWriter, r *http.Request) {
	up := true
	if c, ok := s.client.(interface {
		health(ctx context.Context) error
	}); ok {
		ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
		defer cancel()
		up = c.health(ctx) == nil
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"status":  "ok",
		"service": "camoflare",
		"version": version,
		"camofox": map[string]any{"up": up},
	})
}

func (s *server) handleV1(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	var req flareRequest
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, maxBodyBytes)).Decode(&req); err != nil {
		s.finish(w, flareResponse{Status: "error", Message: fmt.Sprintf("invalid request body: %v", err)}, start)
		return
	}
	switch req.Cmd {
	case cmdSessionsCreate:
		s.finish(w, s.createSession(&req), start)
	case cmdSessionsList:
		s.finish(w, s.listSessions(), start)
	case cmdSessionsDestroy:
		s.finish(w, s.destroySession(r.Context(), &req), start)
	case cmdRequestGet, cmdRequestPost:
		s.finish(w, s.solve(r.Context(), &req), start)
	default:
		s.finish(w, flareResponse{Status: "error", Message: fmt.Sprintf("unsupported cmd %q", req.Cmd)}, start)
	}
}

func (s *server) finish(w http.ResponseWriter, resp flareResponse, start time.Time) {
	resp.StartTimestamp = start.UnixMilli()
	resp.EndTimestamp = time.Now().UnixMilli()
	resp.Version = version
	writeJSON(w, http.StatusOK, resp)
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}

func errResponse(message string) flareResponse {
	return flareResponse{Status: "error", Message: message}
}

func (s *server) createSession(req *flareRequest) flareResponse {
	id := req.Session
	if id == "" {
		id = randomID("session-")
	}
	var ttl time.Duration
	if req.SessionTTLMinutes != nil && *req.SessionTTLMinutes > 0 {
		ttl = time.Duration(*req.SessionTTLMinutes) * time.Minute
	}
	entry := s.store.getOrCreate(id, ttl, func() string { return "flaresolverr-" + id })
	entry.mu.Lock()
	defer entry.mu.Unlock()

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	tabID, err := s.client.createTab(ctx, entry.userID, s.cfg.sessionKey, "")
	if err != nil {
		s.store.remove(id)
		return errResponse(fmt.Sprintf("create tab failed: %v", err))
	}
	entry.tabID = tabID
	return flareResponse{Status: "ok", Message: "Session created successfully.", Session: id}
}

func (s *server) listSessions() flareResponse {
	sessions := s.store.list()
	if sessions == nil {
		sessions = []string{}
	}
	return flareResponse{Status: "ok", Message: "", Sessions: sessions}
}

func (s *server) destroySession(ctx context.Context, req *flareRequest) flareResponse {
	if req.Session == "" {
		return errResponse("session is required")
	}
	entry, ok := s.store.get(req.Session)
	if !ok {
		return errResponse(fmt.Sprintf("session %q not found", req.Session))
	}
	entry.mu.Lock()
	defer entry.mu.Unlock()
	destroyCtx, cancel := context.WithTimeout(ctx, 15*time.Second)
	defer cancel()
	if err := s.client.destroySession(destroyCtx, entry.userID); err != nil && !isNotFound(err) {
		s.logger.Warn("destroy camofox session failed", "session", req.Session, "err", err)
	}
	s.store.remove(req.Session)
	return flareResponse{Status: "ok", Message: "Session destroyed.", Session: req.Session}
}

// solve implements request.get / request.post: drive one Camofox tab to the
// target URL, wait out the challenge, and harvest HTML, cookies and agent.
func (s *server) solve(ctx context.Context, req *flareRequest) flareResponse {
	if req.URL == "" {
		return errResponse("url is required")
	}
	target, err := url.Parse(req.URL)
	if err != nil || target.Host == "" {
		return errResponse(fmt.Sprintf("invalid url %q", req.URL))
	}
	maxTimeout := req.MaxTimeout
	if maxTimeout <= 0 {
		maxTimeout = defaultMaxTimeout
	}
	var ttl time.Duration
	if req.SessionTTLMinutes != nil && *req.SessionTTLMinutes > 0 {
		ttl = time.Duration(*req.SessionTTLMinutes) * time.Minute
	}

	ephemeral := req.Session == ""
	sessionID := req.Session
	if ephemeral {
		sessionID = randomID("ephemeral-")
	}
	entry := s.store.getOrCreate(sessionID, ttl, func() string {
		if ephemeral {
			return "camoflare-ephemeral-" + sessionID
		}
		return "flaresolverr-" + sessionID
	})
	entry.ephemeral = ephemeral

	entry.mu.Lock()
	defer entry.mu.Unlock()
	if entry.expired(time.Now()) {
		return errResponse(fmt.Sprintf("session %q expired", req.Session))
	}

	deadlineCtx, cancel := context.WithDeadline(ctx, time.Now().Add(
		time.Duration(maxTimeout)*time.Millisecond+2*time.Minute))
	defer cancel()

	if len(req.Cookies) > 0 {
		if err := s.importCookies(deadlineCtx, entry, target, req.Cookies); err != nil {
			return s.failEphemeral(entry, err.Error())
		}
	}

	page, err := s.loadPage(deadlineCtx, entry, req)
	if err != nil {
		return s.failEphemeral(entry, err.Error())
	}

	wait := 0
	if req.WaitInSeconds != nil && *req.WaitInSeconds > 0 {
		wait = *req.WaitInSeconds
	}
	solution, err := s.awaitSolution(deadlineCtx, entry, page, time.Duration(maxTimeout)*time.Millisecond, wait)
	if err != nil {
		return s.failEphemeral(entry, err.Error())
	}

	if req.ReturnScreenshot {
		return s.failEphemeral(entry, "screenshots are client-side: camoflare returns cookies only")
	}

	resp := flareResponse{Status: "ok", Message: "", Solution: solution}
	if ephemeral {
		s.teardownEphemeral(deadlineCtx, entry)
	}
	return resp
}

func (s *server) failEphemeral(entry *sessionEntry, message string) flareResponse {
	if entry.ephemeral {
		ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()
		s.teardownEphemeral(ctx, entry)
	}
	return errResponse(message)
}

func (s *server) teardownEphemeral(ctx context.Context, entry *sessionEntry) {
	_ = s.client.destroySession(ctx, entry.userID)
	s.store.remove(entry.id)
}

func (s *server) importCookies(ctx context.Context, entry *sessionEntry, target *url.URL, cookies []flareCookie) error {
	imports := make([]cookieImport, 0, len(cookies))
	for _, cookie := range cookies {
		if cookie.Name == "" {
			return fmt.Errorf("cookie with empty name")
		}
		domain := cookie.Domain
		if domain == "" {
			domain = target.Hostname()
		}
		imp := cookieImport{
			Name:   cookie.Name,
			Value:  cookie.Value,
			Domain: domain,
		}
		if cookie.Path != "" {
			imp.Path = cookie.Path
		}
		if cookie.Expires != nil {
			imp.Expires = cookie.Expires
		}
		imp.HTTPOnly = cookie.HTTPOnly
		imp.Secure = cookie.Secure
		imports = append(imports, imp)
	}
	if err := s.client.importCookies(ctx, entry.userID, imports); err != nil {
		return fmt.Errorf("import cookies failed: %w", err)
	}
	return nil
}

// loadPage ensures a live tab and navigates it. Camofox recycles tabs and
// expires idle sessions server-side, so a 404 anywhere means "recreate once
// and retry" rather than a hard failure.
func (s *server) loadPage(ctx context.Context, entry *sessionEntry, req *flareRequest) (*url.URL, error) {
	target, _ := url.Parse(req.URL)
	if entry.tabID == "" {
		tabID, err := s.client.createTab(ctx, entry.userID, s.cfg.sessionKey, req.URL)
		if err != nil {
			return nil, fmt.Errorf("create tab failed: %w", err)
		}
		entry.tabID = tabID
	} else if err := s.client.navigate(ctx, entry.userID, entry.tabID, req.URL); isNotFound(err) {
		tabID, cerr := s.client.createTab(ctx, entry.userID, s.cfg.sessionKey, req.URL)
		if cerr != nil {
			return nil, fmt.Errorf("recreate tab failed: %w", cerr)
		}
		entry.tabID = tabID
	} else if err != nil {
		return nil, fmt.Errorf("navigate failed: %w", err)
	}

	if req.Cmd == cmdRequestPost && req.PostData != nil && *req.PostData != "" {
		quotedURL, _ := json.Marshal(req.URL)
		quotedBody, _ := json.Marshal(*req.PostData)
		expr := fmt.Sprintf(`(async () => {
  const r = await fetch(%s, {method: "POST", headers: {"Content-Type": "application/x-www-form-urlencoded"}, body: %s, credentials: "same-origin"});
  const t = await r.text();
  document.open(); document.write(t); document.close();
  return r.status;
})()`, quotedURL, quotedBody)
		if _, err := s.evaluateRecreating(ctx, entry, req.URL, expr); err != nil {
			return nil, fmt.Errorf("post body submit failed: %w", err)
		}
	}
	return target, nil
}

func (s *server) evaluateRecreating(ctx context.Context, entry *sessionEntry, pageURL, expr string) (any, error) {
	result, err := s.client.evaluate(ctx, entry.userID, entry.tabID, expr)
	if isNotFound(err) {
		tabID, cerr := s.client.createTab(ctx, entry.userID, s.cfg.sessionKey, pageURL)
		if cerr != nil {
			return nil, cerr
		}
		entry.tabID = tabID
		if nerr := s.client.navigate(ctx, entry.userID, entry.tabID, pageURL); nerr != nil {
			return nil, nerr
		}
		return s.client.evaluate(ctx, entry.userID, entry.tabID, expr)
	}
	return result, err
}

// extractExpr harvests everything request.get needs in a single evaluate
// round trip.
const extractExpr = `(() => ({html: (document.documentElement ? document.documentElement.outerHTML : ""), url: location.href, title: document.title, cookie: document.cookie, userAgent: navigator.userAgent}))()`

type pageState struct {
	html      string
	pageURL   string
	title     string
	cookie    string
	userAgent string
}

func pageStateFrom(result any) pageState {
	m, _ := result.(map[string]any)
	str := func(key string) string {
		text, _ := m[key].(string)
		return text
	}
	return pageState{
		html:      str("html"),
		pageURL:   str("url"),
		title:     str("title"),
		cookie:    str("cookie"),
		userAgent: str("userAgent"),
	}
}

// awaitSolution polls the page until the challenge clears or maxTimeout
// elapses, then builds the FlareSolverr solution object.
func (s *server) awaitSolution(ctx context.Context, entry *sessionEntry, target *url.URL, maxTimeout time.Duration, waitSeconds int) (*flareSolution, error) {
	deadline := time.Now().Add(maxTimeout)
	var state pageState
	for {
		result, err := s.evaluateRecreating(ctx, entry, target.String(), extractExpr)
		if err != nil {
			return nil, fmt.Errorf("extract page failed: %w", err)
		}
		state = pageStateFrom(result)
		if !challengeDetected(state.title, state.html) {
			break
		}
		if time.Now().After(deadline) {
			state = pageStateFrom(result)
			break
		}
		select {
		case <-ctx.Done():
			return nil, fmt.Errorf("solve cancelled: %w", ctx.Err())
		case <-time.After(pollInterval):
		}
	}
	if challengeDetected(state.title, state.html) {
		return nil, fmt.Errorf("challenge not solved in %dms (title %q)", maxTimeout.Milliseconds(), state.title)
	}

	if waitSeconds > 0 {
		select {
		case <-ctx.Done():
			return nil, fmt.Errorf("solve cancelled: %w", ctx.Err())
		case <-time.After(time.Duration(waitSeconds) * time.Second):
		}
		if result, err := s.evaluateRecreating(ctx, entry, target.String(), extractExpr); err == nil {
			state = pageStateFrom(result)
		}
	}

	finalURL := state.pageURL
	if finalURL == "" {
		finalURL = target.String()
	}
	parsed, err := url.Parse(finalURL)
	if err != nil || parsed.Host == "" {
		parsed = target
		finalURL = target.String()
	}
	secure := parsed.Scheme == "https"
	solution := &flareSolution{
		URL:       finalURL,
		Cookies:   parseDocumentCookie(state.cookie, parsed.Hostname(), secure),
		UserAgent: state.userAgent,
	}
	// document.cookie hides HttpOnly cookies (cf_clearance always is one),
	// so prefer the storage_state export when the VNC plugin is enabled.
	// Clearance cookies can land in the context slightly after the page
	// first reads as solved, so retry briefly instead of a single shot.
	if exported := s.exportCookies(ctx, entry); len(exported) > 0 {
		solution.Cookies = exported
	}
	return solution, nil
}

// exportCookies fetches the storage_state export, retrying while it comes
// back empty. Returns nil when the endpoint is unavailable (VNC plugin
// disabled) so callers keep the document.cookie fallback.
func (s *server) exportCookies(ctx context.Context, entry *sessionEntry) []flareCookie {
	timeout := s.cfg.exportTimeout
	if timeout <= 0 {
		timeout = 15 * time.Second
	}
	interval := s.cfg.exportInterval
	if interval <= 0 {
		interval = time.Second
	}
	deadline := time.Now().Add(timeout)
	for {
		exported, err := s.client.storageState(ctx, entry.userID)
		if err != nil {
			s.logger.Warn("storage_state export failed, keeping document.cookie fallback", "err", err)
			return nil
		}
		if len(exported) > 0 {
			return exported
		}
		if time.Now().After(deadline) {
			return nil
		}
		select {
		case <-ctx.Done():
			return nil
		case <-time.After(interval):
		}
	}
}

// challengeDetected spots Cloudflare / DDoS-GUARD interstitials. It errs
// toward "challenged" on the classic markers only; page copy that merely
// mentions Cloudflare without a verification flow is not flagged.
func challengeDetected(title, html string) bool {
	lowerTitle := strings.ToLower(title)
	if strings.Contains(lowerTitle, "just a moment") {
		return true
	}
	lowerHTML := strings.ToLower(html)
	if strings.Contains(lowerHTML, "__cf_chl") || strings.Contains(lowerHTML, "cf-chl-") {
		return true
	}
	if strings.Contains(lowerHTML, "cloudflare") &&
		(strings.Contains(lowerHTML, "verifying you are human") ||
			strings.Contains(lowerHTML, "checking your browser") ||
			strings.Contains(lowerHTML, "verify you are human")) {
		return true
	}
	if strings.Contains(lowerHTML, "ddos-guard") &&
		(strings.Contains(lowerHTML, "checking your browser") ||
			strings.Contains(lowerHTML, "verifying")) {
		return true
	}
	return false
}

// parseDocumentCookie turns a document.cookie header into FlareSolverr
// cookie objects. The browser never exposes flags or expiry through
// document.cookie, so the result is host-scoped session cookies; replay
// them with the returned User-Agent or clearance will re-trigger.
func parseDocumentCookie(header, domain string, secure bool) []flareCookie {
	cookies := []flareCookie{}
	for _, pair := range strings.Split(header, ";") {
		pair = strings.TrimSpace(pair)
		if pair == "" {
			continue
		}
		name, value, _ := strings.Cut(pair, "=")
		name = strings.TrimSpace(name)
		if name == "" {
			continue
		}
		cookies = append(cookies, flareCookie{
			Name:   name,
			Value:  strings.TrimSpace(value),
			Domain: domain,
			Path:   "/",
			Secure: secure,
		})
	}
	return cookies
}
