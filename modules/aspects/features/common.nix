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
      boot.kernelModules = [ "tcp_bbr" ];
      boot.kernel.sysctl = {
        "net.core.default_qdisc" = "fq";
        "net.ipv4.tcp_congestion_control" = "bbr";
      };

      environment.systemPackages = with pkgs; [
        parted
        efibootmgr
      ];
    };
  };
}
