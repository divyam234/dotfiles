{ den, ... }:
{
  den.aspects.redis = _: {
    nixosSecrets = [ "redis/password" ];

    nixos =
      {
        containers,
        pkgs,
        secrets,
        ...
      }:
      {
        sops.templates."redis.env" = secrets.mkTemplate {
          name = "redis.env";
          content = ''
            REDIS_PASSWORD=${secrets.redis.password}
          '';
        };

        virtualisation.quadlet.containers.redis = {
          containerConfig = {
            image = "docker.io/bitnami/redis";
            networkAliases = [ "redis" ];
            environmentFiles = [ "${containers.secretDir}/redis.env" ];
            volumes = [ "${containers.dataRoot}/redis:/bitnami/redis/data" ];
            healthCmd = "redis-cli -a $REDIS_PASSWORD ping | grep -q PONG";
          };
          serviceConfig = {
            ExecStartPre = "${pkgs.coreutils}/bin/install -d -m 0750 -o 1001 -g 0 ${containers.dataRoot}/redis";
            MemoryMax = "512M";
            CPUQuota = "100%";
          };
        };
      };
  };
}
