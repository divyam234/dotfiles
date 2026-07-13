{ den, ... }:
{
  den.aspects.common = {
    includes = [
      den.aspects.zsh
      den.aspects.nix
      den.aspects.fish
      den.aspects.git
      den.aspects.ssh
      den.aspects.starship
    ];

    nixos = { pkgs, ... }: {
      environment.systemPackages = with pkgs; [
        parted
        efibootmgr
      ];
    };
  };
}
