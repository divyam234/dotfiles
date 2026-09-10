{ den, ... }:
{
  den.aspects.camofox = { user, ... }: {
    nixos =
      {
        config,
        containers,
        pkgs,
        secrets,
        ...
      }:
      let
        quadlet = config.virtualisation.quadlet;
      in
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
          autoStart = true;
          containerConfig = {
            name = "camofox-browser";
            image = "ghcr.io/jo-inc/camofox-browser:latest";
            healthCmd = "none";
            networks = [ quadlet.networks.${containers.networkName}.ref ];
            networkAliases = [ "camofox-browser" ];
            environmentFiles = [ "${containers.secretDir}/camofox.env" ];
            environments = {
              CAMOFOX_BIND_HOST = "0.0.0.0";
              CAMOFOX_PORT = "9377";
              MAX_OLD_SPACE_SIZE = "2048";
            };
            publishPorts = [ "9377:9377" ];
            volumes = [ "${containers.dataRoot}/camofox:/root/.camofox" ];
            autoUpdate = "registry";
          };
          serviceConfig = {
            ExecStartPre = "${pkgs.coreutils}/bin/install -d -m 0750 -o ${user.userName} -g users ${containers.dataRoot}/camofox";
            Restart = "always";
            RestartSec = "10s";
            NoNewPrivileges = true;
            MemoryMax = "3G";
            CPUQuota = "200%";
          };
        };
      };
  };
}
