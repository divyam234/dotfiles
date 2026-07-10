{ den, ... }:
{
  den.aspects.fish = {
    homeManager =
      { pkgs, config, ... }:
      {
        home.packages = with pkgs; [
          fish
          nix-your-shell
        ];

        programs = {
          fish = {
            enable = true;
            generateCompletions = false;
            interactiveShellInit = ''
              fish_vi_key_bindings
              set -g fish_greeting ""
              set -gx EDITOR nvim
              set -gx VISUAL nvim
              set -gx MANPAGER "nvim +Man!"
              set -gx NH_FLAKE "$HOME/dotfiles"
              complete -c dot -f -a '(command just --justfile "$HOME/dotfiles/justfile" --working-directory "$HOME/dotfiles" --summary 2>/dev/null)'
              if command -q nix-your-shell
                nix-your-shell fish | source
              end
            '';
            shellAliases = {
              la = "eza -a --color=always --group-directories-first --icons";
              ll = "eza -l --color=always --group-directories-first --icons";
              ls = "eza -al --color=always --group-directories-first --icons";
              lt = "eza -aT --color=always --group-directories-first --icons";
              cat = "bat";
              grep = "rg";
              find = "fd";
              gs = "git status --short --branch";
              ga = "git add";
              gc = "git commit";
              gp = "git push";
              gl = "git log --oneline --graph --decorate";
              lg = "lazygit";
              nfu = "nix flake update";
              oc = "opencode";
              zj = "zellij";
              ".." = "cd ..";
              "..." = "cd ../..";
              "...." = "cd ../../..";
              "....." = "cd ../../../..";
              "......" = "cd ../../../../..";
            };
            functions = {
              fish_greeting = "";
              mkcd = ''
                mkdir -p $argv[1]
                cd $argv[1]
              '';
              envsource = ''
                for line in (cat $argv | grep -v '^#' | grep '=')
                  set item (string split -m 1 '=' $line)
                  set -gx $item[1] $item[2]
                end
              '';
              dot = ''
                set -l repo "$HOME/dotfiles"
                set -l justfile "$repo/justfile"

                if not test -f "$justfile"
                  printf 'dot: missing %s\n' "$justfile" >&2
                  return 1
                end

                if test (count $argv) -eq 0
                  command just --justfile "$justfile" --working-directory "$repo" --list
                else
                  command just --justfile "$justfile" --working-directory "$repo" $argv
                end
              '';
            };
          };
          zoxide = {
            enable = true;
            enableFishIntegration = true;
          };
          fzf = {
            enable = true;
            enableFishIntegration = true;
          };
          direnv = {
            enable = true;
            nix-direnv.enable = true;
          };
        };
      };
  };
}
