package main

import "github.com/spf13/cobra"

func (a *app) pushCommand() *cobra.Command {
	return &cobra.Command{
		Use: "push", Short: "Stage, commit, and push the local checkout using omp",
		Args: cobra.NoArgs, ValidArgsFunction: noCompletions,
		RunE: func(cmd *cobra.Command, _ []string) error {
			if err := a.execute(cmd, "git", []string{"add", "."}); err != nil {
				return err
			}
			return a.execute(cmd, "omp", []string{"--no-session", "commit", "--no-changelog", "--push"})
		},
	}
}
