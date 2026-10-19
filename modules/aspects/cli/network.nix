{ den, ... }:
{
  den.aspects.network-tools = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          aria2
          bind.dnsutils
          hydra
          cloudflared
          curl
          curlie
          doggo
          gost
          gping
          httpie
          ipcalc
          iperf3
          mtr
          net-tools
          nmap
          openssl
          rsync
          socat
          tcpdump
          teldrive-bin
          wget
          whois
        ];
      };
  };
}
