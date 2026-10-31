package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestRemoteActivationWorkflow(t *testing.T) {
	for _, action := range []string{"test", "switch", "boot"} {
		for _, scenario := range []string{"existing", "clone", "clone-failure", "pull-failure", "activation-failure", "not-checkout", "explicit-path", "environment-path"} {
			t.Run(action+"/"+scenario, func(t *testing.T) {
				a, calls, _ := testApp(t)
				t.Setenv("DOTFILES_DIR", "/missing-local-checkout")
				home := t.TempDir()
				repo := filepath.Join(home, "dotfiles")
				remoteEnv := ""
				args := []string{action, "netcup"}
				if scenario == "explicit-path" || scenario == "environment-path" {
					repo = filepath.Join(home, "repo with 'quotes'; $(touch injected)")
					if scenario == "explicit-path" {
						args = append(args, "--repo", repo)
					} else {
						remoteEnv = repo
					}
				}
				if scenario != "clone" && scenario != "clone-failure" {
					dir := filepath.Join(repo, ".git")
					if scenario == "not-checkout" {
						dir = repo
					}
					if err := os.MkdirAll(dir, 0o755); err != nil {
						t.Fatal(err)
					}
				}
				if _, err := execute(a, args...); err != nil {
					t.Fatal(err)
				}
				if len(*calls) != 1 || (*calls)[0].Tool != "ssh" || (*calls)[0].Dir != "" || len((*calls)[0].Args) != 4 {
					t.Fatalf("unexpected invocation: %#v", *calls)
				}
				bin := t.TempDir()
				log := filepath.Join(home, "commands")
				// Run only the SSH payload locally, with fake git and nh commands.
				git := `#!/bin/sh
printf 'git %s\n' "$*" >> "$TEST_LOG"
case "$1" in
  clone)
    [ "$SCENARIO" != clone-failure ] || exit 21
    [ "$2" = -- ] && [ "$3" = 'https://github.com/divyam234/dotfiles.git' ] || exit 22
    mkdir -p "$4/.git"
    ;;
  pull)
    [ "$PWD" = "$EXPECTED_REPO" ] && [ "$2" = --ff-only ] || exit 23
    [ "$SCENARIO" != pull-failure ] || exit 24
    ;;
  *) exit 25 ;;
esac
`
				nh := `#!/bin/sh
[ "$PWD" = "$EXPECTED_REPO" ] || exit 26
printf 'nh %s\n' "$*" >> "$TEST_LOG"
[ "$SCENARIO" != activation-failure ] || exit 27
`
				for name, body := range map[string]string{"git": git, "nh": nh} {
					if err := os.WriteFile(filepath.Join(bin, name), []byte(body), 0o755); err != nil {
						t.Fatal(err)
					}
				}
				cmd := exec.Command("sh", "-c", (*calls)[0].Args[3])
				cmd.Dir = home
				cmd.Env = append(os.Environ(), "HOME="+home, "DOTFILES_DIR="+remoteEnv,
					"PATH="+bin+":"+os.Getenv("PATH"), "TEST_LOG="+log, "EXPECTED_REPO="+repo, "SCENARIO="+scenario)
				out, err := cmd.CombinedOutput()
				fail := strings.HasSuffix(scenario, "failure") || scenario == "not-checkout"
				if (err != nil) != fail {
					t.Fatalf("unexpected result: err=%v, output=%s", err, out)
				}
				data, readErr := os.ReadFile(log)
				if readErr != nil && !os.IsNotExist(readErr) {
					t.Fatal(readErr)
				}
				want := ""
				if scenario == "clone" || scenario == "clone-failure" {
					want += "git clone -- " + cloneURL + " " + repo + "\n"
				}
				if scenario != "clone-failure" && scenario != "not-checkout" {
					want += "git pull --ff-only\n"
					if scenario != "pull-failure" {
						want += "nh os " + action + " . -H netcup\n"
					}
				}
				if string(data) != want {
					t.Fatalf("commands=%q, want=%q", data, want)
				}
				if _, err := os.Stat(filepath.Join(home, "injected")); !os.IsNotExist(err) {
					t.Fatal("repository path was executed as code")
				}
			})
		}
	}
}
