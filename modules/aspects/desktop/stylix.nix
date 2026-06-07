
{ inputs, den, ... }:
{
  den.aspects.stylix = {
    nixos = { pkgs, ... }: {
      imports = [ inputs.stylix.nixosModules.stylix ];
      stylix = {
        enable = true;
        image = ../../../theme/wallpaper.png;
        base16Scheme = ../../../theme/generated/base16.yaml;
        polarity = "dark";
        fonts = {
          monospace = { package = pkgs.nerd-fonts.jetbrains-mono; name = "JetBrainsMono Nerd Font"; };
          sansSerif = { package = pkgs.inter; name = "Inter"; };
          serif = { package = pkgs.merriweather; name = "Merriweather"; };
        };
        targets = {
          # KDE/Qt is the active desktop. Stylix owns broad theme propagation;
          # Matugen only generates the palette consumed by Stylix.
        };
      };
    };
  };
}
