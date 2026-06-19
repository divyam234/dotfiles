{ inputs, den, ... }:
{
  flake-file.inputs.noctalia = {
    url = "github:noctalia-dev/noctalia";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.noctalia = {
    nixos =
      { lib, pkgs, ... }:
      {
        nix.settings = {
          extra-substituters = [ "https://noctalia.cachix.org" ];
          extra-trusted-public-keys = [
            "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
          ];
        };

        environment.systemPackages = [
          inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
        ];
      };

    homeManager =
      { pkgs, ... }:
      {
        imports = [ inputs.noctalia.homeModules.default ];

        home.packages = [ inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default ];

        programs.noctalia = {
          enable = true;

          # Niri starts the shell. Do not create a second lifecycle owner.
          systemd.enable = false;

          # Keep the declarative layer small. GUI changes remain writable in
          # ~/.local/state/noctalia/settings.toml and override these defaults.
          settings = {
            theme = {
              mode = "dark";
              source = "wallpaper";
              wallpaper_scheme = "m3-content";
            };

            wallpaper = {
              enabled = true;
              default.path = "${../../../theme/wallpaper.png}";
            };
          };
        };
      };
  };
}
