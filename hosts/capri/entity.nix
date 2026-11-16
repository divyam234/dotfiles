_: {
  den.hosts.aarch64-linux.capri = {
    dns = {
      refreshInterval = "5m";
      publicTarget = {
        ipv4.enable = false;
        ipv6 = {
          enable = true;
          source = "local";
        };
      };
    };
    tailscale.exitNode = true;
    rcloneWebdav.cacheDir = "/mnt/drive/rclone";
    rcloneWebdav.teldriveApiHost = "http://127.0.0.1:8090";
    users.bhunter = { };
  };
}
