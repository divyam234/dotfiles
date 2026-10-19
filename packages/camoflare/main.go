// Command camoflare is a FlareSolverr-compatible challenge-solving proxy
// backed by a Camofox browser server.
package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

// version is overridden at link time from the Nix package version.
var version = "dev"

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	cfg := configFromEnv()
	client := newCamofoxClient(cfg.camofoxURL, cfg.accessKey, cfg.apiKey, cfg.httpTimeout)
	srv := newServer(cfg, client, logger)

	httpSrv := &http.Server{
		Addr:              cfg.listen,
		Handler:           srv.routes(),
		ReadHeaderTimeout: 10 * time.Second,
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	go func() {
		logger.Info("camoflare listening",
			"addr", cfg.listen,
			"camofox", cfg.camofoxURL,
			"version", version,
		)
		if err := httpSrv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Error("listen failed", "err", err)
			stop()
		}
	}()

	<-ctx.Done()
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	_ = httpSrv.Shutdown(shutdownCtx)
	srv.store.close()
}
