{ den, ... }:
{
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
            lang.nix.enable = true;
            lang.python = {
              enable = true;
              installDependencies = true;
            };
            lang.go = {
              enable = true;
              installDependencies = true;
            };
            lang.typescript = {
              enable = true;
              installDependencies = false;
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
