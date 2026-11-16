{ den, ... }:
{
  den.schema.host =
    { lib, ... }:
    {
      options.librespot = lib.mkOption {
        type = lib.types.submodule {
          options = {
            cacheDir = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Directory librespot uses for its cache; defaults to librespot under the user's XDG cache directory.";
            };
          };
        };
        default = { };
        description = "Host-specific librespot settings.";
      };
    };

  den.aspects.librespot = { host, user, ... }: {
    nixos =
      { lib, ... }:
      {
        networking.firewall = {
          allowedTCPPorts = [ 24879 ];
          allowedUDPPorts = [ 5353 ];
        };

        systemd.tmpfiles.rules = lib.optionals (host.librespot.cacheDir != null) [
          "d ${host.librespot.cacheDir} 0750 ${user.userName} users -"
        ];
      };

    homeManager =
      { config, ... }:
      {
        services.librespot = {
          enable = true;
          settings = {
            name = host.hostName;
            backend = "pulseaudio";
            device-type = "speaker";
            bitrate = 320;
            cache =
              if host.librespot.cacheDir == null then
                "${config.xdg.cacheHome}/librespot"
              else
                host.librespot.cacheDir;
            zeroconf-port = 24879;
          };
        };
      };
  };
}
