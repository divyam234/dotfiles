package main

import (
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	"github.com/spf13/cobra"
)

func TestPullLocal(t *testing.T) {
	for _, args := range [][]string{{"pull"}, {"pull", "laptop"}} {
		a, calls, repo := testApp(t)
		if _, err := execute(a, args...); err != nil {
			t.Fatal(err)
		}
		want := []invocation{{repo, "git", []string{"pull", "--ff-only"}}}
		if !reflect.DeepEqual(*calls, want) {
			t.Fatalf("got %#v, want %#v", *calls, want)
		}
	}
}

func TestPullRemotePaths(t *testing.T) {
	for _, mode := range []string{"home", "environment", "explicit"} {
		t.Run(mode, func(t *testing.T) {
			a, calls, _ := testApp(t)
			t.Setenv("DOTFILES_DIR", "/missing-local-checkout")
			home := t.TempDir()
			remoteRepo := filepath.Join(home, "dotfiles")
			remoteEnv := ""
			args := []string{"pull", "netcup"}
			if mode != "home" {
				remoteRepo = filepath.Join(home, "repo with 'quotes'; $(touch injected)")
				if mode == "environment" {
					remoteEnv = remoteRepo
				} else {
					args = append(args, "--repo", remoteRepo)
				}
			}
			if _, err := execute(a, args...); err != nil {
				t.Fatal(err)
			}
			if len(*calls) != 1 {
				t.Fatalf("calls=%#v", *calls)
			}
			call := (*calls)[0]
			if call.Tool != "ssh" || call.Dir != "" || len(call.Args) != 3 || call.Args[0] != "--" || call.Args[1] != "netcup" {
				t.Fatalf("unexpected SSH invocation: %#v", call)
			}
			// Execute only the generated shell command against a fake Git, never SSH.
			bin := t.TempDir()
			if err := os.WriteFile(filepath.Join(bin, "git"), []byte("#!/bin/sh\nprintf '%s\\n' \"$@\"\n"), 0o755); err != nil {
				t.Fatal(err)
			}
			cmd := exec.Command("sh", "-c", call.Args[2])
			cmd.Dir = home
			cmd.Env = append(os.Environ(), "HOME="+home, "DOTFILES_DIR="+remoteEnv, "PATH="+bin+":"+os.Getenv("PATH"))
			out, err := cmd.CombinedOutput()
			if err != nil || string(out) != "-C\n"+remoteRepo+"\npull\n--ff-only\n" {
				t.Fatalf("output=%q, err=%v", out, err)
			}
			if _, err := os.Stat(filepath.Join(home, "injected")); !os.IsNotExist(err) {
				t.Fatal("repository path was interpreted as shell code")
			}
		})
	}
}

func TestPullRejectsInvalidTargets(t *testing.T) {
	for _, args := range [][]string{{"pull", "unknown"}, {"pull", "netcup", "extra"}} {
		a, calls, _ := testApp(t)
		a.hostname = func() (string, error) { t.Fatal("unexpected hostname lookup"); return "", nil }
		if _, err := execute(a, args...); err == nil || len(*calls) != 0 {
			t.Fatalf("err=%v, calls=%#v", err, *calls)
		}
	}
}

func TestPullFailures(t *testing.T) {
	a, calls, _ := testApp(t)
	a.hostname = func() (string, error) { return "", errors.New("unavailable") }
	if _, err := execute(a, "pull", "netcup"); err == nil || !strings.Contains(err.Error(), "hostname") || len(*calls) != 0 {
		t.Fatalf("err=%v, calls=%#v", err, *calls)
	}
	want := errors.New("SSH or Git failed")
	a.hostname = func() (string, error) { return "workstation", nil }
	a.run = func(_ *cobra.Command, _, _ string, _ []string) error { return want }
	if _, err := execute(a, "pull", "netcup"); !errors.Is(err, want) {
		t.Fatalf("got %v, want %v", err, want)
	}
}
