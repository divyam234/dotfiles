
{ den, ... }:
{
  den.aspects.fonts = {
    nixos = { pkgs, ... }: {
      fonts = {
        fontDir.enable = true;
        packages = with pkgs; [
          inter
          merriweather
          nerd-fonts.jetbrains-mono
          nerd-fonts.fira-code
          noto-fonts
          noto-fonts-cjk-sans
          noto-fonts-color-emoji
        ];
      };
    };
  };
}
