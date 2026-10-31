package main

import (
	"bytes"
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
)

func TestCacheRefreshCommand(t *testing.T) {
	a, calls, _ := testApp(t)
	t.Setenv("DOTFILES_DIR", "/missing")
	var requests atomic.Int64
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requests.Add(1)
		if r.Method != http.MethodPost || r.URL.Path != "/-/refresh" {
			t.Errorf("wrong request: %s %s", r.Method, r.URL.Path)
		}
		fmt.Fprintf(w, `{"sha256":%q,"generated_at":"2026-10-31T12:00:00Z","paths":42}`, strings.Repeat("a", 64))
	}))
	defer server.Close()
	out, err := execute(a, "cache", "refresh", "--url", server.URL+"/")
	if err != nil || !strings.Contains(out, "Cache refreshed: sha256:") || !strings.Contains(out, "42 paths") || !strings.Contains(out, "2026-10-31T12:00:00Z") {
		t.Fatalf("output=%q, err=%v", out, err)
	}
	if requests.Load() != 1 || len(*calls) != 0 {
		t.Fatalf("requests=%d, subprocess calls=%#v", requests.Load(), *calls)
	}
}

func TestCacheRefreshFailures(t *testing.T) {
	for _, tt := range []struct {
		name, body, want string
		status           int
	}{
		{"unavailable", "retaining current index: download failed", "HTTP 502", http.StatusBadGateway},
		{"old-proxy", "404 page not found", "HTTP 404", http.StatusNotFound},
		{"invalid-json", "not JSON", "decode cache refresh result", http.StatusOK},
		{"missing-identity", `{}`, "no index identity", http.StatusOK},
	} {
		t.Run(tt.name, func(t *testing.T) {
			a, calls, _ := testApp(t)
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				w.WriteHeader(tt.status)
				fmt.Fprint(w, tt.body)
			}))
			defer server.Close()
			out, err := execute(a, "cache", "refresh", "--url", server.URL)
			if err == nil || !strings.Contains(err.Error(), tt.want) || out != "" || len(*calls) != 0 {
				t.Fatalf("output=%q, err=%v, calls=%#v", out, err, *calls)
			}
		})
	}
	t.Run("cancelled", func(t *testing.T) {
		ctx, cancel := context.WithCancel(context.Background())
		cancel()
		var out bytes.Buffer
		err := refreshCache(ctx, http.DefaultClient, "http://127.0.0.1:1", &out)
		if err == nil || out.Len() != 0 {
			t.Fatalf("output=%q, err=%v", out.String(), err)
		}
	})
}
