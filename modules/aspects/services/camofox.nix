{ den, ... }:
{
  den.aspects.camofox = { user, ... }: {
    nixosSecrets = [
      "camofox/access_key"
      "camofox/admin_key"
      "camofox/api_key"
    ];

    nixos =
      {
        containers,
        pkgs,
        secrets,
        ...
      }:
      {
        sops.templates."camofox.env" = secrets.mkTemplate {
          name = "camofox.env";
          content = ''
            CAMOFOX_ACCESS_KEY=${secrets.camofox.access_key}
            CAMOFOX_ADMIN_KEY=${secrets.camofox.admin_key}
            CAMOFOX_API_KEY=${secrets.camofox.api_key}
          '';
        };

        virtualisation.quadlet.containers.camofox-browser = {
          containerConfig = {
            image = "ghcr.io/jo-inc/camofox-browser:latest";
            healthCmd = "none";
            networkAliases = [ "camofox-browser" ];
            environmentFiles = [ "${containers.secretDir}/camofox.env" ];
            environments = {
              CAMOFOX_BIND_HOST = "0.0.0.0";
              CAMOFOX_PORT = "9377";
              MAX_OLD_SPACE_SIZE = "2048";
              ENABLE_VNC = "1";
            };
            publishPorts = [
              "9377:9377"
              # Raw VNC listens on container loopback only (no password); the
              # bridge below relays it to the container address for farsee.
              "5900:5900"
            ];
            volumes = [ "${containers.dataRoot}/camofox:/root/.camofox" ];
          };
          serviceConfig = {
            ExecStartPre = "${pkgs.coreutils}/bin/install -d -m 0750 -o ${user.userName} -g users ${containers.dataRoot}/camofox";
            MemoryMax = "3G";
            CPUQuota = "200%";
          };
        };

        virtualisation.quadlet.containers.camofox-vnc-bridge = {
          containerConfig = {
            image = "docker.io/alpine/socat:latest";
            networks = [ "container:camofox-browser" ];
            exec = [
              "TCP-LISTEN:5900,fork,reuseaddr"
              "TCP:127.0.0.1:5900"
            ];
          };
          unitConfig = {
            After = [ "camofox-browser.service" ];
            Requires = [ "camofox-browser.service" ];
          };
          serviceConfig = {
            MemoryMax = "64M";
            CPUQuota = "20%";
          };
        };
      };
  };
}
