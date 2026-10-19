{ den, ... }:
{
  den.aspects.librespot = { host, user, ... }: {
    nixos = _: {
      networking.firewall = {
        allowedTCPPorts = [ 24879 ];
        allowedUDPPorts = [ 5353 ];
      };
      systemd.tmpfiles.rules = [
        "d /mnt/drive/librespot 0750 ${user.userName} users -"
        "d /mnt/drive/librespot/cache 0750 ${user.userName} users -"
      ];
      systemd.services.systemd-tmpfiles-setup.unitConfig.RequiresMountsFor = [ "/mnt/drive" ];
    };

    homeManager = _: {
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
