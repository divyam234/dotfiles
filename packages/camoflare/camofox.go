package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// browserAPI is the subset of the Camofox REST API camoflare drives.
// The *camofoxClient below implements it against HTTP; tests stub it.
type browserAPI interface {
	createTab(ctx context.Context, userID, sessionKey, pageURL string) (string, error)
	navigate(ctx context.Context, userID, tabID, pageURL string) error
	evaluate(ctx context.Context, userID, tabID, expression string) (any, error)
	importCookies(ctx context.Context, userID string, cookies []cookieImport) error
	destroySession(ctx context.Context, userID string) error
	// storageState exports full-fidelity cookies (including HttpOnly)
	// via the VNC plugin's GET /sessions/:userId/storage_state endpoint.
	storageState(ctx context.Context, userID string) ([]flareCookie, error)
}

// cookieImport matches the Camofox POST /sessions/:userId/cookies schema:
// name, value and domain are required; the rest is optional.
type cookieImport struct {
	Name     string `json:"name"`
	Value    string `json:"value"`
	Domain   string `json:"domain"`
	Path     string `json:"path,omitempty"`
	Expires  *int64 `json:"expires,omitempty"`
	HTTPOnly bool   `json:"httpOnly,omitempty"`
	Secure   bool   `json:"secure,omitempty"`
	SameSite string `json:"sameSite,omitempty"`
}

type camofoxError struct {
	Status int
	Body   string
}

func (e *camofoxError) Error() string {
	return fmt.Sprintf("camofox: unexpected status %d: %s", e.Status, e.Body)
}

func isNotFound(err error) bool {
	var ce *camofoxError
	return errors.As(err, &ce) && ce.Status == http.StatusNotFound
}

type camofoxClient struct {
	base      string
	accessKey string
	apiKey    string
	http      *http.Client
}

func newCamofoxClient(baseURL, accessKey, apiKey string, timeout time.Duration) *camofoxClient {
	return &camofoxClient{
		base:      strings.TrimSuffix(baseURL, "/"),
		accessKey: accessKey,
		apiKey:    apiKey,
		http:      &http.Client{Timeout: timeout},
	}
}

func (c *camofoxClient) request(ctx context.Context, method, path string, query url.Values, body any, bearer string) (any, error) {
	var reader io.Reader
	if body != nil {
		raw, err := json.Marshal(body)
		if err != nil {
			return nil, fmt.Errorf("camofox: encode request: %w", err)
		}
		reader = bytes.NewReader(raw)
	}
	target := c.base + path
	if len(query) > 0 {
		target += "?" + query.Encode()
	}
	req, err := http.NewRequestWithContext(ctx, method, target, reader)
	if err != nil {
		return nil, fmt.Errorf("camofox: build request: %w", err)
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	// Callers pass an explicit bearer for endpoints with their own key
	// surface (cookie import); everything else uses the global access key.
	key := bearer
	if key == "" {
		key = c.accessKey
	}
	if key != "" {
		req.Header.Set("Authorization", "Bearer "+key)
	}
	return c.roundTrip(req)
}

func (c *camofoxClient) roundTrip(req *http.Request) (any, error) {
	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("camofox: request failed: %w", err)
	}
	defer resp.Body.Close()
	raw, err := io.ReadAll(io.LimitReader(resp.Body, 32<<20))
	if err != nil {
		return nil, fmt.Errorf("camofox: read response: %w", err)
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, &camofoxError{Status: resp.StatusCode, Body: string(raw)}
	}
	if len(bytes.TrimSpace(raw)) == 0 {
		return nil, nil
	}
	var decoded any
	if err := json.Unmarshal(raw, &decoded); err != nil {
		return nil, fmt.Errorf("camofox: decode response: %w", err)
	}
	return decoded, nil
}

func field(payload any, key string) (any, bool) {
	m, ok := payload.(map[string]any)
	if !ok {
		return nil, false
	}
	value, ok := m[key]
	return value, ok
}

func stringField(payload any, key string) string {
	value, ok := field(payload, key)
	if !ok {
		return ""
	}
	text, _ := value.(string)
	return text
}

func (c *camofoxClient) createTab(ctx context.Context, userID, sessionKey, pageURL string) (string, error) {
	body := map[string]any{"userId": userID, "sessionKey": sessionKey}
	if pageURL != "" {
		body["url"] = pageURL
	}
	payload, err := c.request(ctx, http.MethodPost, "/tabs", nil, body, "")
	if err != nil {
		return "", err
	}
	tabID := stringField(payload, "tabId")
	if tabID == "" {
		return "", fmt.Errorf("camofox: create tab returned no tabId: %v", payload)
	}
	return tabID, nil
}

func (c *camofoxClient) navigate(ctx context.Context, userID, tabID, pageURL string) error {
	_, err := c.request(ctx, http.MethodPost, "/tabs/"+tabID+"/navigate", nil,
		map[string]any{"userId": userID, "url": pageURL}, "")
	return err
}

func (c *camofoxClient) evaluate(ctx context.Context, userID, tabID, expression string) (any, error) {
	payload, err := c.request(ctx, http.MethodPost, "/tabs/"+tabID+"/evaluate", nil,
		map[string]any{"userId": userID, "expression": expression}, "")
	if err != nil {
		return nil, err
	}
	if result, ok := field(payload, "result"); ok {
		return result, nil
	}
	if errText := stringField(payload, "error"); errText != "" {
		return nil, fmt.Errorf("camofox: evaluate failed: %s", errText)
	}
	return payload, nil
}

func (c *camofoxClient) importCookies(ctx context.Context, userID string, cookies []cookieImport) error {
	if c.apiKey == "" {
		return errors.New("camofox: cookie import requested but CAMOFOX_API_KEY is not configured")
	}
	_, err := c.request(ctx, http.MethodPost, "/sessions/"+userID+"/cookies", nil,
		map[string]any{"cookies": cookies}, c.apiKey)
	return err
}

func (c *camofoxClient) destroySession(ctx context.Context, userID string) error {
	_, err := c.request(ctx, http.MethodDelete, "/sessions/"+userID, nil, nil, "")
	return err
}

// storageState exports the session's cookies with full fidelity. It needs
// the VNC plugin (ENABLE_VNC=1) on the Camofox server; without it the
// endpoint answers 404 and callers must fall back to document.cookie.
func (c *camofoxClient) storageState(ctx context.Context, userID string) ([]flareCookie, error) {
	payload, err := c.request(ctx, http.MethodGet, "/sessions/"+userID+"/storage_state", nil, nil, "")
	if err != nil {
		return nil, err
	}
	raw, ok := field(payload, "cookies")
	if !ok {
		return nil, fmt.Errorf("camofox: storage_state response carried no cookies: %v", payload)
	}
	items, ok := raw.([]any)
	if !ok {
		return nil, fmt.Errorf("camofox: storage_state cookies malformed: %v", raw)
	}
	cookies := make([]flareCookie, 0, len(items))
	for _, item := range items {
		m, ok := item.(map[string]any)
		if !ok {
			continue
		}
		name, _ := m["name"].(string)
		value, _ := m["value"].(string)
		if name == "" {
			continue
		}
		cookie := flareCookie{
			Name:   name,
			Value:  value,
			Domain: stringValue(m["domain"]),
			Path:   stringValue(m["path"]),
		}
		if expires, ok := m["expires"].(float64); ok && expires > 0 {
			secs := int64(expires)
			cookie.Expires = &secs
		}
		cookie.HTTPOnly, _ = m["httpOnly"].(bool)
		cookie.Secure, _ = m["secure"].(bool)
		cookies = append(cookies, cookie)
	}
	return cookies, nil
}

func stringValue(value any) string {
	text, _ := value.(string)
	return text
}

func (c *camofoxClient) health(ctx context.Context) error {
	_, err := c.request(ctx, http.MethodGet, "/health", nil, nil, "")
	return err
}
