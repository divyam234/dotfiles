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
        virtualisation.quadlet.containers.camofox-browser = {
          secretEnvironment = {
            CAMOFOX_ACCESS_KEY = secrets.camofox.access_key;
            CAMOFOX_ADMIN_KEY = secrets.camofox.admin_key;
            CAMOFOX_API_KEY = secrets.camofox.api_key;
          };
          containerConfig = {
            image = "ghcr.io/jo-inc/camofox-browser:latest";
            healthCmd = "none";
            networkAliases = [ "camofox-browser" ];
            environments = {
              CAMOFOX_BIND_HOST = "0.0.0.0";
              CAMOFOX_PORT = "9377";
              MAX_OLD_SPACE_SIZE = "2048";
              ENABLE_VNC = "1";
            };
            publishPorts = [
              "9377:9377"
              "5900:5901"
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
              "TCP-LISTEN:5901,fork,reuseaddr"
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
