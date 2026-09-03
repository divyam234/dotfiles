{
  bhunterUser,
  entityLib,
  ...
}:
{
  den.hosts.aarch64-linux.netcup = {
    hostName = "netcup";
    user = "bhunter";
    domain = "bhunter.tech";
    secretsFile = ../../../hosts/netcup/secrets.yaml;
    dns.publicTarget.ipv4.source = "local";
    tailscale.autoconnect = true;
    teldrive.download = {
      bots = 4;
      clientPool = true;
    };
    caddy.cacheDir = "/var/cache/caddy";
    instantiate = entityLib.mkNixos "aarch64-linux";

    users.bhunter = bhunterUser // {
      classes = [ "homeManager" ];
    };
  };
}
