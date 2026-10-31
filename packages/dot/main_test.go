package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"reflect"
	"slices"
	"strconv"
	"strings"
	"syscall"
	"testing"

	"github.com/spf13/cobra"
)

type invocation struct {
	Dir, Tool string
	Args      []string
}

func testApp(t *testing.T) (*app, *[]invocation, string) {
	t.Helper()
	repo := filepath.Join(t.TempDir(), "repo with spaces")
	if err := os.Mkdir(repo, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(repo, "flake.nix"), nil, 0o644); err != nil {
		t.Fatal(err)
	}
	t.Setenv("DOTFILES_DIR", repo)
	a := newApp(targets{Hosts: []string{"laptop", "netcup"}, Homes: []string{"alice@laptop"}})
	a.hostname = func() (string, error) { return "laptop", nil }
	a.username = func() (string, error) { return "alice", nil }
	calls := new([]invocation)
	a.run = func(_ *cobra.Command, dir, tool string, args []string) error {
		*calls = append(*calls, invocation{dir, tool, args})
		return nil
	}
	return a, calls, repo
}

func execute(a *app, args ...string) (string, error) {
	var output bytes.Buffer
	root := a.command()
	root.SetOut(&output)
	root.SetErr(&output)
	root.SetArgs(args)
	err := root.Execute()
	return output.String(), err
}

func TestDispatch(t *testing.T) {
	tests := []struct {
		args []string
		tool string
		want []string
	}{
		{[]string{"build"}, "nh", []string{"os", "build", ".", "-H", "laptop"}},
		{[]string{"build", "netcup"}, "nh", []string{"os", "build", ".", "-H", "netcup"}},
		{[]string{"switch"}, "nh", []string{"os", "switch", ".", "-H", "laptop"}},
		{[]string{"test"}, "nh", []string{"os", "test", ".", "-H", "laptop"}},
		{[]string{"boot"}, "nh", []string{"os", "boot", ".", "-H", "laptop"}},
		{[]string{"home"}, "nh", []string{"home", "switch", ".", "-c", "alice@laptop"}},
		{[]string{"home", "alice@laptop"}, "nh", []string{"home", "switch", ".", "-c", "alice@laptop"}},
		{[]string{"eval"}, "nix", []string{"eval", `.#nixosConfigurations."laptop".config.system.build.toplevel.drvPath`}},
		{[]string{"eval", "netcup"}, "nix", []string{"eval", `.#nixosConfigurations."netcup".config.system.build.toplevel.drvPath`}},
		{[]string{"eval-hm"}, "nix", []string{"eval", `.#homeConfigurations."alice@laptop".config.home.username`}},
		{[]string{"iso", "laptop"}, "nix", []string{"build", ".#laptop-installer-iso"}},
		{[]string{"fmt"}, "nix", []string{"fmt"}},
		{[]string{"fmt-check"}, "git", []string{"diff", "--check"}},
		{[]string{"show"}, "nix", []string{"flake", "show"}},
		{[]string{"update"}, "nix", []string{"flake", "update"}},
		{[]string{"update-commit"}, "nix", []string{"flake", "update", "--commit-lock-file"}},
		{[]string{"pull"}, "git", []string{"pull", "--ff-only"}},
		{[]string{"clean"}, "nh", []string{"clean", "all"}},
		{[]string{"write-flake"}, "nix", []string{"run", ".#write-flake", "--show-trace"}},
	}
	for _, tt := range tests {
		t.Run(strings.Join(tt.args, " "), func(t *testing.T) {
			a, calls, repo := testApp(t)
			before, err := os.Getwd()
			if err != nil {
				t.Fatal(err)
			}
			if _, err := execute(a, tt.args...); err != nil {
				t.Fatal(err)
			}
			want := []invocation{{repo, tt.tool, tt.want}}
			if !reflect.DeepEqual(*calls, want) {
				t.Fatalf("got %#v, want %#v", *calls, want)
			}
			after, err := os.Getwd()
			if err != nil || after != before {
				t.Fatalf("parent directory changed: %q, %v", after, err)
			}
		})
	}
}

func TestActivationUsesLocalOrRemoteHost(t *testing.T) {
	for _, action := range []string{"test", "switch", "boot"} {
		for _, tt := range []struct {
			name, current, target string
			args                  []string
		}{
			{"default local", "laptop", "laptop", []string{action}},
			{"explicit local", "laptop", "laptop", []string{action, "laptop"}},
			{"explicit remote", "laptop", "netcup", []string{action, "netcup"}},
			{"explicit remote from other machine", "workstation", "netcup", []string{action, "netcup"}},
			{"other machine local", "netcup", "netcup", []string{action, "netcup"}},
		} {
			t.Run(action+"/"+tt.name, func(t *testing.T) {
				a, calls, repo := testApp(t)
				a.hostname = func() (string, error) { return tt.current, nil }
				if _, err := execute(a, tt.args...); err != nil {
					t.Fatal(err)
				}
				wantArgs := []string{"os", action, ".", "-H", tt.target}
				if tt.current != tt.target {
					if len(*calls) != 1 || (*calls)[0].Tool != "ssh" || (*calls)[0].Dir != "" ||
						len((*calls)[0].Args) != 4 || !reflect.DeepEqual((*calls)[0].Args[:3], []string{"-t", "--", tt.target}) {
						t.Fatalf("unexpected remote invocation: %#v", *calls)
					}
					return
				}
				want := []invocation{{repo, "nh", wantArgs}}
				if !reflect.DeepEqual(*calls, want) {
					t.Fatalf("got %#v, want %#v", *calls, want)
				}
			})
		}
	}
}

func TestExplicitActivationHostnameFailureDoesNotRun(t *testing.T) {
	for _, action := range []string{"test", "switch", "boot"} {
		t.Run(action, func(t *testing.T) {
			a, calls, _ := testApp(t)
			a.hostname = func() (string, error) { return "", errors.New("unavailable") }
			_, err := execute(a, action, "netcup")
			if err == nil || !strings.Contains(err.Error(), "determine current hostname") || len(*calls) != 0 {
				t.Fatalf("err=%v, calls=%#v", err, *calls)
			}
		})
	}
}

func TestUnknownActivationTargetsAreRejectedBeforeHostnameLookup(t *testing.T) {
	for _, action := range []string{"test", "switch", "boot"} {
		t.Run(action, func(t *testing.T) {
			a, calls, _ := testApp(t)
			hostnameLookups := 0
			a.hostname = func() (string, error) {
				hostnameLookups++
				return "laptop", nil
			}
			_, err := execute(a, action, "unknown-host")
			if err == nil || hostnameLookups != 0 || len(*calls) != 0 {
				t.Fatalf("err=%v, hostname lookups=%d, calls=%#v", err, hostnameLookups, *calls)
			}
		})
	}
}

func TestRemoteActivationErrorPropagates(t *testing.T) {
	a, calls, _ := testApp(t)
	wantErr := errors.New("remote deployment failed")
	a.run = func(_ *cobra.Command, _ string, _ string, args []string) error {
		*calls = append(*calls, invocation{Args: args})
		return wantErr
	}
	_, err := execute(a, "switch", "netcup")
	if !errors.Is(err, wantErr) || len(*calls) != 1 {
		t.Fatalf("err=%v, calls=%#v", err, *calls)
	}
}

func TestRepositorySelection(t *testing.T) {
	for _, args := range [][]string{{"--repo", "REPO", "build"}, {"build", "--repo", "REPO"}} {
		t.Run(strings.Join(args, " "), func(t *testing.T) {
			a, calls, repo := testApp(t)
			t.Setenv("DOTFILES_DIR", "/missing")
			for i := range args {
				if args[i] == "REPO" {
					args[i] = repo
				}
			}
			if _, err := execute(a, args...); err != nil {
				t.Fatal(err)
			}
			if len(*calls) != 1 || (*calls)[0].Dir != repo {
				t.Fatalf("wrong repository: %#v", *calls)
			}
		})
	}
	t.Run("home default", func(t *testing.T) {
		a, calls, repo := testApp(t)
		home := filepath.Dir(repo)
		if err := os.Rename(repo, filepath.Join(home, "dotfiles")); err != nil {
			t.Fatal(err)
		}
		t.Setenv("DOTFILES_DIR", "")
		t.Setenv("HOME", home)
		if _, err := execute(a, "build"); err != nil {
			t.Fatal(err)
		}
		if (*calls)[0].Dir != filepath.Join(home, "dotfiles") {
			t.Fatalf("wrong default: %#v", *calls)
		}
	})
}

func TestRejectedArgumentsNeverRunTools(t *testing.T) {
	for _, args := range [][]string{
		{"unknown"}, {"check"}, {"flash-iso", "/dev/sda"},
		{"build", "unknown-host"}, {"switch", "unknown-host"}, {"home", "unknown-home"}, {"build", "laptop", "extra"},
		{"update", "extra"}, {"--repo"}, {"--repo", "/missing", "build"}, {"iso"},
		{"build", "--unknown-flag"},
		{"push", "netcup"},
		{"cache", "refresh", "extra"},
	} {
		t.Run(strings.Join(args, " "), func(t *testing.T) {
			a, calls, _ := testApp(t)
			_, err := execute(a, args...)
			if err == nil || exitCode(err) != 2 || len(*calls) != 0 {
				t.Fatalf("err=%v, calls=%#v", err, *calls)
			}
		})
	}
}

func TestDefaultTargetFailures(t *testing.T) {
	for _, name := range []string{"hostname", "username", "unconfigured"} {
		t.Run(name, func(t *testing.T) {
			a, calls, _ := testApp(t)
			switch name {
			case "hostname":
				a.hostname = func() (string, error) { return "", errors.New("unavailable") }
			case "username":
				a.username = func() (string, error) { return "", errors.New("unavailable") }
			case "unconfigured":
				a.hostname = func() (string, error) { return "unknown", nil }
			}
			if _, err := execute(a, "home"); err == nil || len(*calls) != 0 {
				t.Fatalf("err=%v, calls=%#v", err, *calls)
			}
		})
	}
}

func TestHelpAndCompletionNeedNoRepository(t *testing.T) {
	for _, args := range [][]string{
		nil, {"--help"}, {"build", "--help"}, {"completion", "fish"},
		{"cache", "--help"}, {"cache", "refresh", "--help"}, {"__complete", "cache", ""},
		{"__complete", "build", ""}, {"__complete", "home", "alice"},
	} {
		t.Run(strings.Join(args, " "), func(t *testing.T) {
			a, calls, _ := testApp(t)
			t.Setenv("DOTFILES_DIR", "/missing")
			out, err := execute(a, args...)
			if err != nil || len(out) == 0 || len(*calls) != 0 {
				t.Fatalf("output=%q, err=%v, calls=%#v", out, err, *calls)
			}
			if reflect.DeepEqual(args, []string{"build", "--help"}) && !strings.Contains(out, "dot build [host]") {
				t.Fatalf("not command-specific help: %s", out)
			}
		})
	}
}

func TestCompletionChoices(t *testing.T) {
	for _, tt := range []struct {
		args []string
		want []string
	}{
		{[]string{"build", ""}, []string{"laptop", "netcup"}},
		{[]string{"build", "la"}, []string{"laptop"}},
		{[]string{"build", "laptop", ""}, nil},
		{[]string{"home", ""}, []string{"alice@laptop"}},
		{[]string{"eval-hm", "alice"}, []string{"alice@laptop"}},
		{[]string{"fmt", ""}, nil},
	} {
		t.Run(strings.Join(tt.args, " "), func(t *testing.T) {
			a, calls, _ := testApp(t)
			out, err := execute(a, append([]string{"__complete"}, tt.args...)...)
			if err != nil || len(*calls) != 0 {
				t.Fatalf("err=%v, calls=%#v", err, *calls)
			}
			var choices []string
			for line := range strings.SplitSeq(out, "\n") {
				if line == ":4" {
					break
				}
				choices = append(choices, strings.SplitN(line, "\t", 2)[0])
			}
			if !reflect.DeepEqual(choices, tt.want) {
				t.Fatalf("got %q, want %q; output=%q", choices, tt.want, out)
			}
		})
	}
}

func TestRepositoryDirectoryCompletion(t *testing.T) {
	dir := t.TempDir()
	for _, name := range []string{"repo one", "repo-two", "other"} {
		if err := os.Mkdir(filepath.Join(dir, name), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.WriteFile(filepath.Join(dir, "repo-file"), nil, 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(filepath.Join(dir, "other"), filepath.Join(dir, "repo-link")); err != nil {
		t.Fatal(err)
	}
	a, calls, _ := testApp(t)
	out, err := execute(a, "__complete", "--repo", filepath.Join(dir, "repo"))
	if err != nil || len(*calls) != 0 {
		t.Fatalf("err=%v, calls=%#v", err, *calls)
	}
	for _, name := range []string{"repo one", "repo-two", "repo-link"} {
		if !strings.Contains(out, filepath.Join(dir, name)+"/\n") {
			t.Fatalf("missing directory %q: %s", name, out)
		}
	}
	if strings.Contains(out, "repo-file") {
		t.Fatalf("file offered as directory: %s", out)
	}
}

// A real child process without shell scripts or external tools.
func TestProcessHelper(t *testing.T) {
	if os.Getenv("DOT_PROCESS_HELPER") != "1" {
		return
	}
	if os.Getenv("DOT_PROCESS_SIGNAL") == "1" {
		_ = syscall.Kill(os.Getpid(), syscall.SIGTERM)
		select {}
	}
	input, err := io.ReadAll(os.Stdin)
	if err != nil {
		os.Exit(100)
	}
	dir, err := os.Getwd()
	if err != nil {
		os.Exit(101)
	}
	separator := slices.Index(os.Args, "--")
	_ = json.NewEncoder(os.Stdout).Encode(struct {
		Dir, Input string
		Args       []string
	}{dir, string(input), os.Args[separator+1:]})
	fmt.Fprint(os.Stderr, "child stderr")
	code, _ := strconv.Atoi(os.Getenv("DOT_PROCESS_EXIT"))
	os.Exit(code)
}

func TestProcessIOAndExitStatus(t *testing.T) {
	for _, code := range []int{0, 37} {
		t.Run(strconv.Itoa(code), func(t *testing.T) {
			t.Setenv("DOT_PROCESS_HELPER", "1")
			t.Setenv("DOT_PROCESS_EXIT", strconv.Itoa(code))
			var stdout, stderr bytes.Buffer
			cmd := &cobra.Command{}
			cmd.SetContext(context.Background())
			cmd.SetIn(strings.NewReader("interactive input"))
			cmd.SetOut(&stdout)
			cmd.SetErr(&stderr)
			dir := t.TempDir()
			args := []string{"argument with spaces", "$(not-a-shell-command)", "--flag"}
			err := runProcess(cmd, dir, os.Args[0], append([]string{"-test.run=^TestProcessHelper$", "--"}, args...))
			if exitCode(err) != code {
				t.Fatalf("got %v (%d), want %d", err, exitCode(err), code)
			}
			var got struct {
				Dir, Input string
				Args       []string
			}
			if err := json.Unmarshal(stdout.Bytes(), &got); err != nil {
				t.Fatal(err)
			}
			if got.Dir != dir || got.Input != "interactive input" || !reflect.DeepEqual(got.Args, args) || stderr.String() != "child stderr" {
				t.Fatalf("incorrect child IO: %#v, stderr=%q", got, stderr.String())
			}
		})
	}
	t.Run("signal", func(t *testing.T) {
		t.Setenv("DOT_PROCESS_HELPER", "1")
		t.Setenv("DOT_PROCESS_SIGNAL", "1")
		cmd := &cobra.Command{}
		cmd.SetContext(context.Background())
		err := runProcess(cmd, t.TempDir(), os.Args[0], []string{"-test.run=^TestProcessHelper$"})
		if exitCode(err) != 143 {
			t.Fatalf("signal exit: %v (%d)", err, exitCode(err))
		}
	})
	t.Run("missing tool", func(t *testing.T) {
		cmd := &cobra.Command{}
		cmd.SetContext(context.Background())
		err := runProcess(cmd, t.TempDir(), "/no/such/tool", nil)
		if exitCode(err) != 1 {
			t.Fatalf("missing tool: %v (%d)", err, exitCode(err))
		}
	})
}
