{ den, ... }:
{
  den.aspects.redis = _: {
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
        sops.templates."redis.env" = {
          path = "${containers.secretDir}/redis.env";
          mode = "0440";
          content = ''
            REDIS_PASSWORD=${secrets.redis.password}
          '';
        };

        virtualisation.quadlet.containers.redis = {
          autoStart = true;
          containerConfig = {
            name = "redis";
            image = "docker.io/bitnami/redis";
            networks = [ quadlet.networks.${containers.networkName}.ref ];
            networkAliases = [ "redis" ];
            environmentFiles = [ "${containers.secretDir}/redis.env" ];
            volumes = [ "${containers.dataRoot}/redis:/bitnami/redis/data" ];
            healthCmd = "redis-cli -a $REDIS_PASSWORD ping | grep -q PONG";
            autoUpdate = "registry";
          };
          serviceConfig = {
            ExecStartPre = "${pkgs.coreutils}/bin/install -d -m 0750 -o 1001 -g 0 ${containers.dataRoot}/redis";
            Restart = "always";
            RestartSec = "10s";
            NoNewPrivileges = true;
            MemoryMax = "512M";
            CPUQuota = "100%";
          };
        };
      };
  };
}
