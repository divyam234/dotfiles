{ den, ... }:
{
  den.aspects.fish = {
    nixos = { pkgs, ... }: {
      programs.fish.enable = true;
      environment.shells = [ pkgs.fish ];
    };

    homeManager = { pkgs, config, ... }: {
      home.packages = with pkgs; [
        nix-your-shell
      ];

      programs = {
        fish = {
          enable = true;
          interactiveShellInit = ''
            fish_vi_key_bindings
            set -gx EDITOR nvim
            set -gx VISUAL nvim
            set -gx MANPAGER "nvim +Man!"
            set -gx NH_FLAKE "$HOME/dotfiles"
            if command -q nix-your-shell
              nix-your-shell fish | source
            end
          '';
          shellAbbrs = {
            ll = "eza -la --icons --git";
            la = "eza -a --icons";
            lt = "eza --tree --level=2 --icons";
            cat = "bat";
            grep = "rg";
            find = "fd";
            gs = "git status --short --branch";
            ga = "git add";
            gc = "git commit";
            gp = "git push";
            gl = "git log --oneline --graph --decorate";
            lg = "lazygit";
            nrs = "nh os switch";
            nrb = "nh os boot";
            nfu = "nix flake update";
            zj = "zellij";
            zz = "sesh";
          };
          functions = {
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
            rebuild = ''
              set host homepc
              if test (count $argv) -gt 0
                set host $argv[1]
              end
              sudo nixos-rebuild switch --flake $HOME/dotfiles#$host
            '';
            deploy-netcup = ''
              nixos-rebuild switch --flake $HOME/dotfiles#netcup --target-host root@$argv[1] --build-host root@$argv[1] --use-remote-sudo
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
        atuin = {
          enable = true;
          enableFishIntegration = true;
        };
        starship = {
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
