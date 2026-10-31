# dot

`dot` is a small Go + Cobra CLI that manages this flake from any directory
without depending on `just`, Bash, or Fish.
Home Manager installs the executable and its Fish completions together.

```console
dot build laptop
dot switch                 # current hostname
dot home bhunter@laptop
dot fmt
dot --repo /path/to/dotfiles update
```

Use `dot --help` for all commands. `DOTFILES_DIR` overrides the default
`~/dotfiles`; `--repo PATH` takes precedence over both. Repository options go
before or after the command. Commands accept only the arguments shown in help,
not arbitrary flags forwarded to underlying tools.

Host and standalone home targets come from the flake's configuration output
names at package evaluation time and are embedded in the binary. Help and Fish
completions come from the same Cobra command definitions. Completion invokes
only `dot` itself: no Nix evaluation, git/nh commands, or network access.
Rebuild Home Manager after adding a target. Repository overrides use the
installed target list, not the other checkout's live outputs.

`switch`, `test`, `boot`, and `home` activate configurations. `iso` requires an
explicit host; only hosts exposing an installer output can build one. Destructive
disk flashing intentionally remains available only through `just flash-iso`.

`dot` deliberately has no all-machine check command. Command/completion tests
can be run on their own with `nix build .#checks.x86_64-linux.dot`.

For development, run `go test ./...` in `packages/dot`. The checked-in
`targets.json` is empty; unit tests supply their own targets, and Nix replaces
the file with real output names when packaging. Subprocess tests never build
or activate a configuration. `dot completion fish` generates the completion
script installed by Nix; Cobra also supports Bash, Zsh, and PowerShell.

After switching Home Manager, start a new Fish session so an already-loaded old
`dot` function and completion do not shadow the installed command.
