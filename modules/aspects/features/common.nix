{ den, ... }:
{
  den.aspects = {
    common.includes = [
      den.aspects.shell-environment
      den.aspects.host-utilities
      den.aspects.network-performance
      den.aspects.nix
    ];

    shell-environment.includes = [
      den.aspects.zsh
      den.aspects.fish
      den.aspects.git
      den.aspects.ssh
      den.aspects.starship
    ];

    network-performance.nixos = {
      boot.kernelModules = [ "tcp_bbr" ];
      boot.kernel.sysctl = {
        "net.core.default_qdisc" = "fq";
        "net.ipv4.tcp_congestion_control" = "bbr";
      };
    };

    host-utilities.nixos = { pkgs, ... }: {
      environment.systemPackages = with pkgs; [
        parted
        efibootmgr
      ];
    };
  };
}
