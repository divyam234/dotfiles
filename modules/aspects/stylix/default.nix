{ inputs, den, ... }:
{
  flake-file.inputs.stylix = {
    url = "github:nix-community/stylix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  flake-file.inputs.tinted-schemes = {
    url = "github:tinted-theming/schemes";
    flake = false;
  };

  den.aspects.stylix = {
    nixos = {
      imports = [ inputs.stylix.nixosModules.stylix ];
      fonts = {
        enableDefaultPackages = true;
        fontDir.enable = true;
        fontconfig = {
          enable = true;
          useEmbeddedBitmaps = true;
          localConf = ''
            <?xml version="1.0"?>
            <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
            <fontconfig>
              <match target="pattern">
                <test name="family" compare="not_eq">
                  <string>Symbols Nerd Font</string>
                </test>
                <edit name="family" mode="append">
                  <string>Symbols Nerd Font</string>
                </edit>
              </match>
            </fontconfig>
          '';
        };
      };

      stylix = {
        enable = true;
        polarity = "dark";
        base16Scheme = ./nord.yaml;
        homeManagerIntegration = {
          autoImport = false;
          followSystem = false;
        };
      };
    };

    homeManager =
      { pkgs, ... }:
      {
        imports = [ inputs.stylix.homeModules.stylix ];

        fonts.fontconfig.enable = true;

        home.packages = with pkgs; [
          nerd-fonts.jetbrains-mono
          nerd-fonts.symbols-only
          noto-fonts-color-emoji
          inter
        ];

        stylix = {
          enable = true;
          polarity = "dark";
          base16Scheme = ./nord.yaml;
          autoEnable = true;
          cursor = {
            name = "Bibata-Modern-Classic";
            package = pkgs.bibata-cursors;
            size = 24;
          };

          icons = {
            enable = true;
            package = pkgs.papirus-icon-theme;
            dark = "Papirus-Dark";
            light = "Papirus-Dark";
          };

          fonts = {
            sizes = {
              terminal = 14;
              applications = 12;
              popups = 12;
            };
            serif = {
              package = pkgs.merriweather;
              name = "Merriweather";
            };
            sansSerif = {
              package = pkgs.inter;
              name = "Inter";
            };
            monospace = {
              package = pkgs.nerd-fonts.jetbrains-mono;
              name = "JetBrainsMono Nerd Font";
            };
            emoji = {
              package = pkgs.noto-fonts-color-emoji;
              name = "Noto Color Emoji";
            };
          };
        };
      };
  };
}
