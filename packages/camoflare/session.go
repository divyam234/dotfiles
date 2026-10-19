package main

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"sync"
	"time"
)

// sessionEntry maps one FlareSolverr session id onto one Camofox browser
// context (userId) plus the tab used for sequential solves.
type sessionEntry struct {
	id        string
	userID    string
	tabID     string
	ephemeral bool
	expiresAt time.Time
	mu        sync.Mutex
}

func (e *sessionEntry) expired(now time.Time) bool {
	return !e.expiresAt.IsZero() && !now.Before(e.expiresAt)
}

type sessionStore struct {
	mu      sync.RWMutex
	entries map[string]*sessionEntry
	destroy func(ctx context.Context, userID string)
}

func newSessionStore(destroy func(ctx context.Context, userID string)) *sessionStore {
	return &sessionStore{
		entries: make(map[string]*sessionEntry),
		destroy: destroy,
	}
}

func randomID(prefix string) string {
	var raw [16]byte
	_, _ = rand.Read(raw[:])
	return prefix + hex.EncodeToString(raw[:])
}

func (s *sessionStore) get(id string) (*sessionEntry, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	entry, ok := s.entries[id]
	if !ok || entry.expired(time.Now()) {
		return nil, false
	}
	return entry, true
}

// getOrCreate returns the live session for id, rotating it when its TTL
// lapsed, or creates a fresh persistent session when id is unknown.
func (s *sessionStore) getOrCreate(id string, ttl time.Duration, newUserID func() string) *sessionEntry {
	now := time.Now()
	s.mu.Lock()
	defer s.mu.Unlock()
	if entry, ok := s.entries[id]; ok && !entry.expired(now) {
		return entry
	}
	if old, ok := s.entries[id]; ok {
		delete(s.entries, id)
		go s.destroy(context.Background(), old.userID)
	}
	entry := &sessionEntry{id: id, userID: newUserID()}
	if ttl > 0 {
		entry.expiresAt = now.Add(ttl)
	}
	s.entries[id] = entry
	return entry
}

func (s *sessionStore) put(entry *sessionEntry) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.entries[entry.id] = entry
}

func (s *sessionStore) remove(id string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.entries, id)
}

func (s *sessionStore) list() []string {
	now := time.Now()
	s.mu.RLock()
	defer s.mu.RUnlock()
	ids := make([]string, 0, len(s.entries))
	for id, entry := range s.entries {
		if entry.ephemeral || entry.expired(now) {
			continue
		}
		ids = append(ids, id)
	}
	return ids
}

// close sweeps every tracked browser context. Expired entries are destroyed
// with a bounded context so shutdown cannot hang on a wedged browser.
func (s *sessionStore) close() {
	s.mu.Lock()
	entries := make([]*sessionEntry, 0, len(s.entries))
	for _, entry := range s.entries {
		entries = append(entries, entry)
	}
	s.entries = make(map[string]*sessionEntry)
	s.mu.Unlock()
	for _, entry := range entries {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		s.destroy(ctx, entry.userID)
		cancel()
	}
}

func (s *sessionStore) startSweeper(ctx context.Context, interval time.Duration) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case now := <-ticker.C:
			var stale []*sessionEntry
			s.mu.Lock()
			for id, entry := range s.entries {
				if entry.expired(now) {
					stale = append(stale, entry)
					delete(s.entries, id)
				}
			}
			s.mu.Unlock()
			for _, entry := range stale {
				destroyCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
				s.destroy(destroyCtx, entry.userID)
				cancel()
			}
		}
	}
}
