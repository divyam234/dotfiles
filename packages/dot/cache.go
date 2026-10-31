package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/spf13/cobra"
)

func cacheCommand() *cobra.Command {
	cache := &cobra.Command{
		Use: "cache", Short: "Manage the binary cache proxy",
		Args: cobra.NoArgs, ValidArgsFunction: noCompletions,
	}
	var url string
	refresh := &cobra.Command{
		Use: "refresh", Short: "Download and verify the latest binary cache index",
		Args: cobra.NoArgs, ValidArgsFunction: noCompletions,
		RunE: func(cmd *cobra.Command, _ []string) error {
			client := &http.Client{Timeout: 6 * time.Minute}
			return refreshCache(cmd.Context(), client, url, cmd.OutOrStdout())
		},
	}
	refresh.Flags().StringVar(&url, "url", "http://127.0.0.1:7745", "Binary cache proxy URL")
	cache.AddCommand(refresh)
	return cache
}

func refreshCache(ctx context.Context, client *http.Client, url string, out io.Writer) error {
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, strings.TrimRight(url, "/")+"/-/refresh", nil)
	if err != nil {
		return fmt.Errorf("create cache refresh request: %w", err)
	}
	response, err := client.Do(request)
	if err != nil {
		return fmt.Errorf("refresh cache: %w", err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(io.LimitReader(response.Body, 4096))
		return fmt.Errorf("cache refresh failed (HTTP %d): %s", response.StatusCode, strings.TrimSpace(string(body)))
	}
	var result struct {
		SHA256      string `json:"sha256"`
		GeneratedAt string `json:"generated_at"`
		Paths       int    `json:"paths"`
	}
	if err := json.NewDecoder(io.LimitReader(response.Body, 64*1024)).Decode(&result); err != nil {
		return fmt.Errorf("decode cache refresh result: %w", err)
	}
	if result.SHA256 == "" {
		return fmt.Errorf("cache refresh response has no index identity")
	}
	_, err = fmt.Fprintf(out, "Cache refreshed: sha256:%s (generated %s, %d paths)\n", result.SHA256, result.GeneratedAt, result.Paths)
	return err
}
