{ den, ... }:
{
  den.aspects.librespot = {
    includes = [ den.aspects.audio ];

    nixos =
      { host, ... }:
      {
        users.users.${host.user}.linger = true;
        networking.firewall = {
          allowedTCPPorts = [ 24879 ];
          allowedUDPPorts = [ 5353 ];
        };
        systemd.tmpfiles.rules = [
          "d /mnt/drive/librespot/cache 0750 ${host.user} users -"
        ];
        systemd.services.systemd-tmpfiles-setup.unitConfig.RequiresMountsFor = [ "/mnt/drive" ];
      };

    homeManager =
      { host, ... }:
      {
        services.librespot = {
          enable = true;
          settings = {
            name = host.hostName;
            backend = "pulseaudio";
            device-type = "speaker";
            bitrate = 320;
            cache = "/mnt/drive/librespot/cache";
            zeroconf-port = 24879;
          };
        };
      };
  };
}
