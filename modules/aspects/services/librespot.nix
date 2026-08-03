{ den, ... }:
{
  den.aspects.librespot = {
    includes = [ den.aspects.audio ];

    nixos =
      { host, ... }:
      {
        users.users.${host.user}.linger = true;
        systemd.tmpfiles.rules = [
          "d /mnt/drive/librespot/cache 0750 ${host.user} users -"
        ];
      };

    homeManager =
      { host, ... }:
      {
        services.librespot = {
          enable = true;
          settings = {
            name = host.hostName;
            device-type = "speaker";
            bitrate = 320;
            cache = "/mnt/drive/librespot/cache";
          };
        };
      };
  };
}
