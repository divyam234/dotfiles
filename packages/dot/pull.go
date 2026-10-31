package main

import (
	"fmt"
	"slices"
	"strings"

	"github.com/spf13/cobra"
)

func (a *app) pullCommand() *cobra.Command {
	return &cobra.Command{
		Use: "pull [host]", Short: "Fast-forward the local or remote dotfiles checkout",
		Args: cobra.MaximumNArgs(1),
		ValidArgsFunction: func(_ *cobra.Command, args []string, prefix string) ([]string, cobra.ShellCompDirective) {
			var matches []string
			if len(args) == 0 {
				for _, host := range a.targets.Hosts {
					if strings.HasPrefix(host, prefix) {
						matches = append(matches, host)
					}
				}
			}
			return matches, cobra.ShellCompDirectiveNoFileComp
		},
		RunE: func(cmd *cobra.Command, args []string) error {
			if len(args) == 0 {
				return a.execute(cmd, "git", []string{"pull", "--ff-only"})
			}
			host := args[0]
			if !slices.Contains(a.targets.Hosts, host) {
				return fmt.Errorf("unknown target %q; available: %s", host, strings.Join(a.targets.Hosts, ", "))
			}
			current, err := a.hostname()
			if err != nil {
				return fmt.Errorf("determine current hostname: %w", err)
			}
			if host == current {
				return a.execute(cmd, "git", []string{"pull", "--ff-only"})
			}
			// Resolve the default on the remote host, not against the local home
			// directory or DOTFILES_DIR. SSH passes its command through a shell.
			repo := `"${DOTFILES_DIR:-$HOME/dotfiles}"`
			if a.repo != "" {
				repo = quoteShell(a.repo)
			}
			// The login shell may be Fish; use sh for the default expansion.
			remote := "sh -c " + quoteShell("git -C "+repo+" pull --ff-only")
			return a.run(cmd, "", "ssh", []string{"--", host, remote})
		},
	}
}

func quoteShell(value string) string {
	return "'" + strings.ReplaceAll(value, "'", "'\"'\"'") + "'"
}
