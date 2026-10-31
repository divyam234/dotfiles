# dot

`dot` is a small Go + Cobra CLI that manages this flake from any directory
without depending on `just`, Bash, or Fish.
Home Manager installs the executable and its Fish completions together.

```console
dot build laptop
dot switch                 # current hostname
dot home bhunter@laptop
dot fmt
dot cache refresh
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

`dot cache refresh` asks the running binary cache proxy to download, validate,
and save the latest index. It reports the index hash, publication timestamp,
and path count only after success; failures return a nonzero exit status.
No checkout, sudo, or service restart is needed. The default proxy URL is
`http://127.0.0.1:7745`; use `dot cache refresh --url URL` for a different address.
Activate the updated NixOS cache service before using this command. It refreshes
the proxy index, not Nix's separate evaluation or negative narinfo caches.

`switch`, `test`, `boot`, and `home` activate configurations. `iso` requires an
explicit host; only hosts exposing an installer output can build one. Destructive
disk flashing intentionally remains available only through `just flash-iso`.

For `dot test`, `dot switch`, and `dot boot`, a target matching the local
hostname is built and activated locally. A different target deploys the current
local checkout (including untracked files) with `nh`, building on and activating
the target host over SSH. The target's hostname must resolve through normal SSH
configuration and working SSH access (for example, Tailscale MagicDNS/SSH must
be reachable). The remote account must have working privilege escalation for
`nh` to build and activate NixOS. The SSH user is selected by your normal SSH
configuration; `dot` does not hardcode one. `dot build` remains a local build,
even when a host is specified.

`dot pull` fast-forwards the local checkout. `dot pull HOST` does the same
locally when HOST matches this machine; otherwise it runs Git over SSH on HOST,
without activating anything or requiring a local checkout. Remote pulls use the
remote account's `DOTFILES_DIR`, falling back to its `~/dotfiles`. For a different
remote path, use `dot --repo /remote/path pull HOST`. Paths are passed literally;
use an absolute path rather than `~`. The remote checkout must already exist and
have Git upstream authentication configured. Pulls always use `--ff-only` and
never reset or discard changes.

`dot push` runs `omp --no-session commit --no-changelog --push` in the local
checkout selected by `--repo`, `DOTFILES_DIR`, or `~/dotfiles`. It does not accept
a host or use SSH. `omp` must be available on your PATH.

`dot` deliberately has no all-machine check command. Command/completion tests
can be run on their own with `nix build .#checks.x86_64-linux.dot`.

For development, run `go test ./...` in `packages/dot`. The checked-in
`targets.json` is empty; unit tests supply their own targets, and Nix replaces
the file with real output names when packaging. Subprocess tests never build
or activate a configuration. `dot completion fish` generates the completion
script installed by Nix; Cobra also supports Bash, Zsh, and PowerShell.

After switching Home Manager, start a new Fish session so an already-loaded old
`dot` function and completion do not shadow the installed command.
