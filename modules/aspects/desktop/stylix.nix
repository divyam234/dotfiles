
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
          # Stylix is the single theming source across all hosts.
          # DMS shell theming and Niri colors are enabled via stylix targets
          # set in modules/aspects/desktop/dms.nix (HM context).
          # GTK, Qt, and terminals auto-enable via stylix.autoEnable.
        };
      };
    };
  };
}
