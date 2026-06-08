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
          extras.lang.nix.enable = true;
          extraPackages = with pkgs; [
            lua-language-server
            stylua
          ];
        };
      };
  };
}
