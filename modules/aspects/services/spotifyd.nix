{ den, ... }:
{
  den.aspects.spotifyd = { host, user, ... }: {
    nixos = _: {
      users.users.${user.userName}.linger = true;
      networking.firewall = {
        allowedTCPPorts = [ 24879 ];
        allowedUDPPorts = [ 5353 ];
      };
      systemd.tmpfiles.rules = [
        "d /mnt/drive/spotifyd/cache 0750 ${user.userName} users -"
      ];
      systemd.services.systemd-tmpfiles-setup.unitConfig.RequiresMountsFor = [ "/mnt/drive" ];
    };

    homeManager = _: {
      services.spotifyd = {
        enable = true;
        settings = {
          global = {
            device_name = host.hostName;
            device_type = "computer";
            backend = "pulseaudio";
            bitrate = 320;
            cache_path = "/mnt/drive/spotifyd/cache";
            zeroconf_port = 24879;
            use_mpris = true;
          };
        };
      };
    };
  };
}
