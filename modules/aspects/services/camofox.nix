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
            };
            publishPorts = [ "9377:9377" ];
            volumes = [ "${containers.dataRoot}/camofox:/root/.camofox" ];
          };
          serviceConfig = {
            ExecStartPre = "${pkgs.coreutils}/bin/install -d -m 0750 -o ${user.userName} -g users ${containers.dataRoot}/camofox";
            MemoryMax = "3G";
            CPUQuota = "200%";
          };
        };
      };
  };
}
