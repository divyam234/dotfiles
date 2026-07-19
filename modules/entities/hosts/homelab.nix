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
    caddy.cacheDir = "/mnt/drive/caddy-cache";
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
    tailscale.autoconnect = true;

    instantiate = entityLib.mkNixos "x86_64-linux";

    users.bhunter = bhunterUser // {
      classes = [ "homeManager" ];
    };
  };
}
