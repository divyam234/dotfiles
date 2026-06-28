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
    tailscale.autoconnect = true;

    instantiate = entityLib.mkNixos "aarch64-linux";

    users.bhunter = bhunterUser // {
      classes = [ "homeManager" ];
    };
  };
}
