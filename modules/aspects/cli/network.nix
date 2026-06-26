{ den, ... }:
{
  den.aspects.network-tools = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          aria2
          cloudflared
          croc
          curl
          curlie
          doggo
          gping
          httpie
          ipcalc
          iperf3
          mtr
          net-tools
          nmap
          openssl
          rclone
          rsync
          socat
          tcpdump
          wget
          whois
        ];
      };
  };
}
