package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

// fakeBrowser stubs browserAPI with canned page states.
type fakeBrowser struct {
	tabSeq     int
	tabs       map[string]bool
	state      pageState
	challenged bool
	imported   [][]cookieImport
	destroyed  []string
	navigated  []string
	posted     []string
	stored     []flareCookie
	storageSeq [][]flareCookie
	storageErr error
}

func newFake(state pageState) *fakeBrowser {
	return &fakeBrowser{tabs: make(map[string]bool), state: state}
}

func (f *fakeBrowser) createTab(_ context.Context, _, _, _ string) (string, error) {
	f.tabSeq++
	id := "tab-" + string(rune('0'+f.tabSeq))
	f.tabs[id] = true
	return id, nil
}

func (f *fakeBrowser) navigate(_ context.Context, _, tabID, pageURL string) error {
	if !f.tabs[tabID] {
		return &camofoxError{Status: http.StatusNotFound, Body: "no such tab"}
	}
	f.navigated = append(f.navigated, pageURL)
	return nil
}

func (f *fakeBrowser) evaluate(_ context.Context, _, tabID, expr string) (any, error) {
	if !f.tabs[tabID] {
		return nil, &camofoxError{Status: http.StatusNotFound, Body: "no such tab"}
	}
	if strings.HasPrefix(strings.TrimSpace(expr), "(async") {
		f.posted = append(f.posted, expr)
		return float64(200), nil
	}
	m := map[string]any{
		"html":      f.state.html,
		"url":       f.state.pageURL,
		"title":     f.state.title,
		"cookie":    f.state.cookie,
		"userAgent": f.state.userAgent,
	}
	if f.challenged {
		m["title"] = "Just a moment..."
		m["html"] = `<html><body><script>__cf_chl test</script></body></html>`
	}
	return m, nil
}

func (f *fakeBrowser) importCookies(_ context.Context, _ string, cookies []cookieImport) error {
	f.imported = append(f.imported, cookies)
	return nil
}

func (f *fakeBrowser) destroySession(_ context.Context, userID string) error {
	f.destroyed = append(f.destroyed, userID)
	return nil
}

func (f *fakeBrowser) storageState(_ context.Context, _ string) ([]flareCookie, error) {
	if f.storageErr != nil {
		return nil, f.storageErr
	}
	if len(f.storageSeq) > 0 {
		next := f.storageSeq[0]
		f.storageSeq = f.storageSeq[1:]
		return next, nil
	}
	return f.stored, nil
}

func (f *fakeBrowser) health(_ context.Context) error { return nil }

func testServer(fake *fakeBrowser) *server {
	cfg := config{
		sessionKey:     "flaresolverr",
		httpTimeout:    5 * time.Second,
		exportTimeout:  300 * time.Millisecond,
		exportInterval: 10 * time.Millisecond,
	}
	return newServer(cfg, fake, slog.New(slog.NewTextHandler(io.Discard, nil)))
}

func postV1(t *testing.T, srv *server, body string) flareResponse {
	t.Helper()
	req := httptest.NewRequest(http.MethodPost, "/v1", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	srv.routes().ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	var resp flareResponse
	if err := json.NewDecoder(rec.Result().Body).Decode(&resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	return resp
}

func solvedState() pageState {
	return pageState{
		html:      "<html><head><title>Example</title></head><body>hi</body></html>",
		pageURL:   "https://example.com/",
		title:     "Example",
		cookie:    "cf_clearance=abc123; session=xyz",
		userAgent: "TestAgent/1.0",
	}
}

func TestRequestGetSolved(t *testing.T) {
	fake := newFake(solvedState())
	srv := testServer(fake)
	resp := postV1(t, srv, `{"cmd":"request.get","url":"https://example.com/","maxTimeout":5000}`)
	if resp.Status != "ok" {
		t.Fatalf("status = %q (%s), want ok", resp.Status, resp.Message)
	}
	sol := resp.Solution
	if sol == nil {
		t.Fatal("missing solution")
	}
	if sol.URL != "https://example.com/" {
		t.Errorf("solution url = %q, want https://example.com/", sol.URL)
	}
	if len(sol.Cookies) != 2 || sol.Cookies[0].Name != "cf_clearance" {
		t.Errorf("cookies = %+v, want cf_clearance + session", sol.Cookies)
	}
	if sol.Cookies[0].Domain != "example.com" || !sol.Cookies[0].Secure {
		t.Errorf("cookie scope = %+v, want domain example.com secure", sol.Cookies[0])
	}
	if sol.UserAgent != "TestAgent/1.0" {
		t.Errorf("userAgent = %q", sol.UserAgent)
	}
	if len(fake.destroyed) != 1 {
		t.Errorf("ephemeral session not torn down: %v", fake.destroyed)
	}
}

func TestRequestGetChallengeTimeout(t *testing.T) {
	fake := newFake(solvedState())
	fake.challenged = true
	srv := testServer(fake)
	resp := postV1(t, srv, `{"cmd":"request.get","url":"https://example.com/","maxTimeout":100}`)
	if resp.Status != "error" {
		t.Fatalf("status = %q, want error", resp.Status)
	}
	if !strings.Contains(resp.Message, "challenge not solved") {
		t.Errorf("message = %q, want challenge timeout", resp.Message)
	}
}

func TestRequestPostSubmitsForm(t *testing.T) {
	fake := newFake(solvedState())
	srv := testServer(fake)
	resp := postV1(t, srv, `{"cmd":"request.post","url":"https://example.com/login","postData":"a=b&c=d","maxTimeout":5000}`)
	if resp.Status != "ok" {
		t.Fatalf("status = %q (%s), want ok", resp.Status, resp.Message)
	}
	if len(fake.posted) != 1 || !strings.Contains(fake.posted[0], "fetch(") ||
		!strings.Contains(fake.posted[0], "application/x-www-form-urlencoded") {
		t.Errorf("posted exprs = %v, want one form POST fetch", fake.posted)
	}
}

func TestSolutionIsCookiesOnly(t *testing.T) {
	fake := newFake(solvedState())
	fake.stored = []flareCookie{
		{Name: "cf_clearance", Value: "secret", Domain: ".example.com", Secure: true, HTTPOnly: true},
	}
	srv := testServer(fake)
	resp := postV1(t, srv, `{"cmd":"request.get","url":"https://example.com/","returnOnlyCookies":true,"maxTimeout":5000}`)
	if resp.Status != "ok" {
		t.Fatalf("status = %q (%s)", resp.Status, resp.Message)
	}
	encoded, _ := json.Marshal(resp.Solution)
	var keys map[string]any
	_ = json.Unmarshal(encoded, &keys)
	for _, banned := range []string{"response", "headers", "screenshot", "status"} {
		if _, ok := keys[banned]; ok {
			t.Errorf("solution carries %q: %s", banned, encoded)
		}
	}
	if len(resp.Solution.Cookies) != 1 || resp.Solution.UserAgent == "" || resp.Solution.URL == "" {
		t.Errorf("solution = %s, want url+cookies+userAgent only", encoded)
	}
}

func TestSessionsRoundTrip(t *testing.T) {
	fake := newFake(solvedState())
	srv := testServer(fake)

	created := postV1(t, srv, `{"cmd":"sessions.create","session":"s1"}`)
	if created.Status != "ok" || created.Session != "s1" {
		t.Fatalf("create = %+v", created)
	}

	listed := postV1(t, srv, `{"cmd":"sessions.list"}`)
	if len(listed.Sessions) != 1 || listed.Sessions[0] != "s1" {
		t.Fatalf("list = %+v", listed)
	}

	got := postV1(t, srv, `{"cmd":"request.get","url":"https://example.com/","session":"s1","maxTimeout":5000}`)
	if got.Status != "ok" {
		t.Fatalf("solve on session = %+v", got)
	}

	destroyed := postV1(t, srv, `{"cmd":"sessions.destroy","session":"s1"}`)
	if destroyed.Status != "ok" {
		t.Fatalf("destroy = %+v", destroyed)
	}
	if len(fake.destroyed) == 0 {
		t.Error("camofox session not destroyed")
	}
	if resp := postV1(t, srv, `{"cmd":"sessions.destroy","session":"s1"}`); resp.Status != "error" {
		t.Errorf("double destroy = %+v, want error", resp)
	}
}

func TestInvalidURL(t *testing.T) {
	fake := newFake(solvedState())
	srv := testServer(fake)
	resp := postV1(t, srv, `{"cmd":"request.get","url":":///bad"}`)
	if resp.Status != "error" {
		t.Errorf("resp = %+v, want error", resp)
	}
}

func TestChallengeDetected(t *testing.T) {
	cases := []struct {
		name  string
		title string
		html  string
		want  bool
	}{
		{"clear page", "Example Domain", "<html><body>hello</body></html>", false},
		{"mentions cloudflare in copy", "Blog", "<p>how cloudflare tunnels work</p>", false},
		{"just a moment title", "Just a moment...", "<html></html>", true},
		{"managed challenge", "x", `<form id="cf-chl-test"><input name="__cf_chl"></form>`, true},
		{"verifying human", "x", "<div>Cloudflare</div><p>Verifying you are human</p>", true},
		{"ddos guard", "x", "<div>DDoS-GUARD</div><p>Checking your browser</p>", true},
	}
	for _, tc := range cases {
		if got := challengeDetected(tc.title, tc.html); got != tc.want {
			t.Errorf("%s: got %v, want %v", tc.name, got, tc.want)
		}
	}
}

func TestParseDocumentCookie(t *testing.T) {
	got := parseDocumentCookie("cf_clearance=abc=def; session=xyz;  ; =bad", "example.com", true)
	if len(got) != 2 {
		t.Fatalf("got %+v, want 2 cookies", got)
	}
	if got[0].Name != "cf_clearance" || got[0].Value != "abc=def" {
		t.Errorf("first = %+v", got[0])
	}
	if got[0].Domain != "example.com" || got[0].Path != "/" || !got[0].Secure {
		t.Errorf("scope = %+v", got[0])
	}
	if got := parseDocumentCookie("", "example.com", false); len(got) != 0 {
		t.Errorf("empty header gave %+v", got)
	}
}

func TestImportCookiesDefaultsDomain(t *testing.T) {
	fake := newFake(solvedState())
	srv := testServer(fake)
	resp := postV1(t, srv, `{"cmd":"request.get","url":"https://example.com/","cookies":[{"name":"a","value":"b"}],"maxTimeout":5000}`)
	if resp.Status != "ok" {
		t.Fatalf("status = %q (%s)", resp.Status, resp.Message)
	}
	if len(fake.imported) != 1 || len(fake.imported[0]) != 1 {
		t.Fatalf("imported = %+v", fake.imported)
	}
	if fake.imported[0][0].Domain != "example.com" {
		t.Errorf("domain = %q, want example.com", fake.imported[0][0].Domain)
	}
}

func TestRecreatesDeadTab(t *testing.T) {
	fake := newFake(solvedState())
	srv := testServer(fake)
	created := postV1(t, srv, `{"cmd":"sessions.create","session":"s9"}`)
	if created.Status != "ok" {
		t.Fatalf("create = %+v", created)
	}
	// Simulate Camofox recycling the tab server-side.
	entry, _ := srv.store.get("s9")
	delete(fake.tabs, entry.tabID)
	resp := postV1(t, srv, `{"cmd":"request.get","url":"https://example.com/","session":"s9","maxTimeout":5000}`)
	if resp.Status != "ok" {
		t.Fatalf("solve after recycle = %+v", resp)
	}
}

func TestScreenshotRejected(t *testing.T) {
	fake := newFake(solvedState())
	srv := testServer(fake)
	resp := postV1(t, srv, `{"cmd":"request.get","url":"https://example.com/","returnScreenshot":true,"maxTimeout":5000}`)
	if resp.Status != "error" || !strings.Contains(resp.Message, "cookies only") {
		t.Errorf("resp = %+v, want cookies-only rejection", resp)
	}
}

func TestStorageStatePreferredOverDocumentCookie(t *testing.T) {
	fake := newFake(solvedState())
	fake.stored = []flareCookie{
		{Name: "cf_clearance", Value: "secret", Domain: ".example.com", Path: "/", Secure: true, HTTPOnly: true},
	}
	srv := testServer(fake)
	resp := postV1(t, srv, `{"cmd":"request.get","url":"https://example.com/","maxTimeout":5000}`)
	if resp.Status != "ok" {
		t.Fatalf("status = %q (%s)", resp.Status, resp.Message)
	}
	got := resp.Solution.Cookies
	if len(got) != 1 || got[0].Name != "cf_clearance" || !got[0].HTTPOnly || got[0].Domain != ".example.com" {
		t.Errorf("cookies = %+v, want full-fidelity cf_clearance", got)
	}
}

func TestStorageStateRetriesUntilCookiesLand(t *testing.T) {
	fake := newFake(solvedState())
	fake.storageSeq = [][]flareCookie{
		{},
		{},
		{{Name: "cf_clearance", Value: "late", Domain: ".example.com", Secure: true, HTTPOnly: true}},
	}
	srv := testServer(fake)
	resp := postV1(t, srv, `{"cmd":"request.get","url":"https://example.com/","maxTimeout":5000}`)
	if resp.Status != "ok" {
		t.Fatalf("status = %q (%s)", resp.Status, resp.Message)
	}
	got := resp.Solution.Cookies
	if len(got) != 1 || got[0].Name != "cf_clearance" {
		t.Errorf("cookies = %+v, want retried cf_clearance", got)
	}
}

func TestStorageStateFailureKeepsFallback(t *testing.T) {
	fake := newFake(solvedState())
	fake.storageErr = errors.New("plugin disabled")
	srv := testServer(fake)
	resp := postV1(t, srv, `{"cmd":"request.get","url":"https://example.com/","maxTimeout":5000}`)
	if resp.Status != "ok" {
		t.Fatalf("status = %q (%s)", resp.Status, resp.Message)
	}
	if len(resp.Solution.Cookies) != 2 {
		t.Errorf("cookies = %+v, want document.cookie fallback", resp.Solution.Cookies)
	}
}

func TestHealth(t *testing.T) {
	fake := newFake(solvedState())
	srv := testServer(fake)
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	rec := httptest.NewRecorder()
	srv.routes().ServeHTTP(rec, req)
	body, _ := io.ReadAll(rec.Result().Body)
	if !bytes.Contains(body, []byte(`"service":"camoflare"`)) {
		t.Errorf("body = %s", body)
	}
}
