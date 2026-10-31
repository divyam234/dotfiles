package main

import (
	"strings"

	"github.com/spf13/cobra"
)

const cloneURL = "https://github.com/divyam234/dotfiles.git"

func (a *app) remoteActivation(cmd *cobra.Command, host string, args []string) error {
	command := []string{"nh"}
	for _, arg := range args {
		command = append(command, quoteShell(arg))
	}
	script := "set -e\nrepo=" + a.remoteRepo() + "\n" +
		"if [ ! -e \"$repo\" ] && [ ! -L \"$repo\" ]; then\n" +
		"  git clone -- " + quoteShell(cloneURL) + " \"$repo\"\n" +
		"fi\n" +
		"if [ ! -e \"$repo/.git\" ]; then\n" +
		"  echo \"Not a Git checkout: $repo\" >&2\n  exit 1\nfi\n" +
		"cd -- \"$repo\"\n" +
		"git pull --ff-only\n" +
		"exec " + strings.Join(command, " ")
	// A terminal allows nh/sudo to prompt on the remote host.
	return a.run(cmd, "", "ssh", []string{"-t", "--", host, "sh -c " + quoteShell(script)})
}
