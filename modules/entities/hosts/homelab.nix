{
  bhunterUser,
  entityLib,
  ...
}:
{
  den.hosts.x86_64-linux.homelab = {
    hostName = "homelab";
    user = "bhunter";
    tailscale.autoconnect = true;

    instantiate = entityLib.mkNixos "x86_64-linux";

    users.bhunter = bhunterUser // {
      classes = [ "homeManager" ];
    };
  };
}
