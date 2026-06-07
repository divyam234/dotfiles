
{ den, ... }:
{
  den.aspects.gaming = {
    nixos = { pkgs, ... }: {
      programs.steam.enable = true;
      programs.gamemode.enable = true;
      environment.systemPackages = with pkgs; [
        mangohud
        protonup-qt
        heroic
        lutris
      ];
    };
  };
}
