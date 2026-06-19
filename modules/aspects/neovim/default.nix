{ den, ... }:
{
  flake-file.inputs.lazyvim = {
    url = "github:pfassina/lazyvim-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.neovim = {
    homeManager =
      { pkgs, inputs, ... }:
      {
        imports = [
          inputs.lazyvim.homeManagerModules.default
        ];
        programs.lazyvim = {
          enable = true;
          extras = {
            lang = {
              nix.enable = true;
              python = {
                enable = true;
                installDependencies = true;
              };
              go = {
                enable = true;
                installDependencies = true;
              };
              typescript = {
                enable = true;
                installDependencies = false;
              };
            };
          };
          extraPackages = with pkgs; [
            alejandra
          ];
          plugins.colorscheme = ''
            return {
              {
                "LazyVim/LazyVim",
                opts = {
                  -- Stylix configures mini.base16 before LazyVim loads; keep LazyVim from replacing it.
                  colorscheme = function() end,
                },
              },
            }
          '';
        };
      };
  };
}
