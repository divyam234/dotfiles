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
      den.aspects.fish
      den.aspects.git
      den.aspects.ssh
      den.aspects.starship
    ];

    network-performance.nixos = {
      networking.nameservers = [
        "1.1.1.1#cloudflare-dns.com"
        "2606:4700:4700::1111#cloudflare-dns.com"
        "8.8.8.8#dns.google"
        "2001:4860:4860::8888#dns.google"
      ];
      services.resolved = {
        enable = true;
        settings.Resolve = {
          DNSOverTLS = true;
          FallbackDNS = [ ];
          Domains = [ "~." ];
        };
      };
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
