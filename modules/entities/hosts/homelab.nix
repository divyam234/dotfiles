{
  bhunterUser,
  entityLib,
  ...
}:
{
  den.hosts.x86_64-linux.homelab = {
    hostName = "homelab";
    user = "bhunter";
    domain = "bhunter.tech";
    secretsFile = ../../../hosts/homelab/secrets.yaml;
    dns = {
      refreshInterval = "15m";
      publicTarget = {
        ipv4.enable = false;
        ipv6 = {
          enable = true;
          source = "external";
        };
      };
    };
    rcloneWebdav = {
      domain = "media.bhunter.tech";
      remote = "gpix:";
      cacheDir = "/mnt/drive/rclone";
      cacheMaxAge = "8670h";
      cacheMaxSize = "450GiB";
    };
    tailscale.autoconnect = true;

    instantiate = entityLib.mkNixos "x86_64-linux";

    users.bhunter = bhunterUser // {
      classes = [ "homeManager" ];
    };
  };
}
