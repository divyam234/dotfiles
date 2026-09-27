package main

import (
	"os"
	"time"
)

type config struct {
	listen      string
	camofoxURL  string
	accessKey   string
	apiKey      string
	sessionKey  string
	httpTimeout time.Duration
	// exportTimeout bounds the storage_state cookie-settle retry loop;
	// exportInterval is the pause between attempts.
	exportTimeout  time.Duration
	exportInterval time.Duration
}

func configFromEnv() config {
	return config{
		listen:         envOr("CAMOFLARE_LISTEN", ":8191"),
		camofoxURL:     envOr("CAMOFOX_URL", "http://localhost:9377"),
		accessKey:      os.Getenv("CAMOFOX_ACCESS_KEY"),
		apiKey:         os.Getenv("CAMOFOX_API_KEY"),
		sessionKey:     envOr("CAMOFLARE_SESSION_KEY", "flaresolverr"),
		httpTimeout:    35 * time.Second,
		exportTimeout:  15 * time.Second,
		exportInterval: time.Second,
	}
}

func envOr(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
