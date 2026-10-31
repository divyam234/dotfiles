package main

import (
	"bytes"
	_ "embed"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"syscall"

	"github.com/spf13/cobra"
)

// Nix replaces this file at build time with names from the flake outputs.
//
//go:embed targets.json
var targetData []byte

type targets struct {
	Hosts []string `json:"hosts"`
	Homes []string `json:"homes"`
}

type runner func(cmd *cobra.Command, dir, tool string, args []string) error

type app struct {
	targets  targets
	repo     string
	hostname func() (string, error)
	username func() (string, error)
	run      runner
}

func newApp(config targets) *app {
	return &app{
		targets:  config,
		hostname: os.Hostname,
		username: func() (string, error) {
			u, err := user.Current()
			if err != nil {
				return "", err
			}
			return u.Username, nil
		},
		run: runProcess,
	}
}

func (a *app) command() *cobra.Command {
	root := &cobra.Command{
		Use:               "dot",
		Short:             "Manage the dotfiles flake",
		Long:              "Manage the dotfiles flake from any directory.\nRepository: --repo PATH, then DOTFILES_DIR, then ~/dotfiles.\nHost defaults to this machine; home defaults to user@hostname.",
		Args:              cobra.NoArgs,
		SilenceUsage:      true,
		SilenceErrors:     true,
		RunE:              func(cmd *cobra.Command, _ []string) error { return cmd.Help() },
		ValidArgsFunction: noCompletions,
		CompletionOptions: cobra.CompletionOptions{DisableDefaultCmd: true},
	}
	root.PersistentFlags().StringVar(&a.repo, "repo", "", "Dotfiles repository path")
	// Registration cannot fail: the flag exists above and is registered once.
	if err := root.RegisterFlagCompletionFunc("repo", completeDirectories); err != nil {
		panic(err)
	}

	for _, command := range []struct{ name, description string }{
		{"build", "Build NixOS without activating"},
		{"switch", "Build and activate NixOS permanently"},
		{"test", "Activate NixOS until reboot"},
		{"boot", "Install NixOS for the next boot"},
	} {
		root.AddCommand(a.targetCommand(command.name+" [host]", command.description,
			a.targets.Hosts, a.hostname, "nh", func(target string) []string {
				return []string{"os", command.name, ".", "-H", target}
			}))
	}
	root.AddCommand(a.targetCommand("home [user@host]", "Build and activate standalone Home Manager",
		a.targets.Homes, a.defaultHome, "nh", func(target string) []string {
			return []string{"home", "switch", ".", "-c", target}
		}))
	root.AddCommand(a.targetCommand("eval [host]", "Evaluate NixOS",
		a.targets.Hosts, a.hostname, "nix", func(target string) []string {
			return []string{"eval", ".#nixosConfigurations." + strconv.Quote(target) + ".config.system.build.toplevel.drvPath"}
		}))
	root.AddCommand(a.targetCommand("eval-hm [user@host]", "Evaluate standalone Home Manager",
		a.targets.Homes, a.defaultHome, "nix", func(target string) []string {
			return []string{"eval", ".#homeConfigurations." + strconv.Quote(target) + ".config.home.username"}
		}))
	root.AddCommand(a.targetCommand("iso HOST", "Build an installer ISO (explicit host required)",
		a.targets.Hosts, nil, "nix", func(target string) []string {
			return []string{"build", ".#" + target + "-installer-iso"}
		}))

	root.AddCommand(a.simpleCommand("fmt", "Format tracked Nix files", "nix", "fmt"))
	root.AddCommand(a.simpleCommand("fmt-check", "Check diff whitespace", "git", "diff", "--check"))
	root.AddCommand(a.simpleCommand("show", "Show flake outputs", "nix", "flake", "show"))
	root.AddCommand(a.simpleCommand("update", "Update flake inputs", "nix", "flake", "update"))
	root.AddCommand(a.simpleCommand("update-commit", "Update inputs and commit the lock file", "nix", "flake", "update", "--commit-lock-file"))
	root.AddCommand(a.simpleCommand("pull", "Pull with fast-forward only", "git", "pull", "--ff-only"))
	root.AddCommand(a.simpleCommand("clean", "Clean old Nix generations using nh", "nh", "clean", "all"))
	root.AddCommand(a.simpleCommand("write-flake", "Regenerate flake.nix", "nix", "run", ".#write-flake", "--show-trace"))
	root.AddCommand(&cobra.Command{
		Use: "completion SHELL", Short: "Generate shell completions",
		ValidArgs: []string{"bash", "fish", "powershell", "zsh"},
		Args:      cobra.MatchAll(cobra.ExactArgs(1), cobra.OnlyValidArgs),
		RunE: func(cmd *cobra.Command, args []string) error {
			switch args[0] {
			case "bash":
				return root.GenBashCompletionV2(cmd.OutOrStdout(), true)
			case "fish":
				return writeFishCompletion(root, cmd.OutOrStdout())
			case "powershell":
				return root.GenPowerShellCompletionWithDesc(cmd.OutOrStdout())
			default:
				return root.GenZshCompletion(cmd.OutOrStdout())
			}
		},
	})
	return root
}

func writeFishCompletion(root *cobra.Command, out io.Writer) error {
	var script bytes.Buffer
	if err := root.GenFishCompletion(&script, true); err != nil {
		return err
	}
	// Cobra 1.10.2 evaluates the request without escaping prior arguments.
	// Preserve quoted paths (and prevent their contents being treated as code).
	const original = "set -l args (commandline -opc)"
	if strings.Count(script.String(), original) != 1 {
		return errors.New("Cobra Fish template changed; review argument escaping")
	}
	_, err := io.WriteString(out, strings.Replace(script.String(), original,
		"set -l args (commandline -opc | string escape)", 1))
	return err
}

func completeDirectories(_ *cobra.Command, _ []string, prefix string) ([]string, cobra.ShellCompDirective) {
	// Cobra's Fish template doesn't implement FilterDirs, so return directory
	// candidates directly instead of falling back to general file completion.
	dir, base := filepath.Split(prefix)
	searchDir := dir
	if searchDir == "" {
		searchDir = "."
	}
	entries, err := os.ReadDir(searchDir)
	if err != nil {
		return nil, cobra.ShellCompDirectiveNoFileComp
	}
	var matches []string
	for _, entry := range entries {
		if !strings.HasPrefix(entry.Name(), base) {
			continue
		}
		info, err := os.Stat(filepath.Join(searchDir, entry.Name()))
		if err == nil && info.IsDir() {
			matches = append(matches, dir+entry.Name()+string(filepath.Separator))
		}
	}
	return matches, cobra.ShellCompDirectiveNoFileComp
}

func (a *app) simpleCommand(name, description, tool string, args ...string) *cobra.Command {
	return &cobra.Command{
		Use: name, Short: description, Args: cobra.NoArgs,
		ValidArgsFunction: noCompletions,
		RunE: func(cmd *cobra.Command, _ []string) error {
			return a.execute(cmd, tool, args)
		},
	}
}

func (a *app) targetCommand(use, description string, choices []string, defaultTarget func() (string, error), tool string, arguments func(string) []string) *cobra.Command {
	validate := cobra.MaximumNArgs(1)
	if defaultTarget == nil {
		validate = cobra.ExactArgs(1)
	}
	return &cobra.Command{
		Use: use, Short: description, Args: validate,
		ValidArgsFunction: func(_ *cobra.Command, args []string, prefix string) ([]string, cobra.ShellCompDirective) {
			var matches []string
			if len(args) == 0 {
				for _, target := range choices {
					if strings.HasPrefix(target, prefix) {
						matches = append(matches, target)
					}
				}
			}
			return matches, cobra.ShellCompDirectiveNoFileComp
		},
		RunE: func(cmd *cobra.Command, args []string) error {
			var target string
			if len(args) == 1 {
				target = args[0]
			} else {
				var err error
				target, err = defaultTarget()
				if err != nil {
					return fmt.Errorf("determine default target: %w", err)
				}
			}
			if !slices.Contains(choices, target) {
				return fmt.Errorf("unknown target %q; available: %s", target, strings.Join(choices, ", "))
			}
			return a.execute(cmd, tool, arguments(target))
		},
	}
}

func noCompletions(*cobra.Command, []string, string) ([]string, cobra.ShellCompDirective) {
	return nil, cobra.ShellCompDirectiveNoFileComp
}

func (a *app) defaultHome() (string, error) {
	username, err := a.username()
	if err != nil {
		return "", err
	}
	hostname, err := a.hostname()
	if err != nil {
		return "", err
	}
	return username + "@" + hostname, nil
}

func (a *app) execute(cmd *cobra.Command, tool string, args []string) error {
	repo := a.repo
	if repo == "" {
		repo = os.Getenv("DOTFILES_DIR")
	}
	if repo == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return fmt.Errorf("find home directory: %w", err)
		}
		repo = filepath.Join(home, "dotfiles")
	}
	repo, err := filepath.Abs(repo)
	if err != nil {
		return fmt.Errorf("resolve repository: %w", err)
	}
	info, err := os.Stat(filepath.Join(repo, "flake.nix"))
	if err != nil {
		return fmt.Errorf("no accessible flake.nix in %q (use --repo PATH or DOTFILES_DIR): %w", repo, err)
	}
	if !info.Mode().IsRegular() {
		return fmt.Errorf("flake.nix in %q is not a regular file", repo)
	}
	return a.run(cmd, repo, tool, args)
}

type processError struct{ err error }

func (e *processError) Error() string { return e.err.Error() }
func (e *processError) Unwrap() error { return e.err }

func runProcess(cmd *cobra.Command, dir, tool string, args []string) error {
	child := exec.CommandContext(cmd.Context(), tool, args...)
	child.Dir = dir
	child.Stdin = cmd.InOrStdin()
	child.Stdout = cmd.OutOrStdout()
	child.Stderr = cmd.ErrOrStderr()
	if err := child.Run(); err != nil {
		return &processError{fmt.Errorf("%s: %w", tool, err)}
	}
	return nil
}

func exitCode(err error) int {
	if err == nil {
		return 0
	}
	var process *processError
	if errors.As(err, &process) {
		var status *exec.ExitError
		if errors.As(err, &status) {
			if status.ExitCode() >= 0 {
				return status.ExitCode()
			}
			if state, ok := status.Sys().(syscall.WaitStatus); ok && state.Signaled() {
				return 128 + int(state.Signal())
			}
		}
		return 1
	}
	return 2
}

func main() {
	var config targets
	if err := json.Unmarshal(targetData, &config); err != nil {
		fmt.Fprintln(os.Stderr, "dot: invalid embedded targets:", err)
		os.Exit(2)
	}
	err := newApp(config).command().Execute()
	if err != nil {
		fmt.Fprintln(os.Stderr, "dot:", err)
	}
	os.Exit(exitCode(err))
}
