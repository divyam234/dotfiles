{ den, ... }:
{
  den.aspects.siyuan = {
    includes = [ den.aspects.oci-service ];
    nixos =
      {
        config,
        lib,
        host,
        ...
      }:
      let
        quadlet = config.virtualisation.quadlet;
        containers = config.dot.containers;
      in
      {
        dot.containers.dataDirs.siyuan = {
          inherit (containers.owners.home) user group;
        };
        virtualisation.quadlet.containers.siyuan = {
          autoStart = true;
          containerConfig = {
            name = "siyuan";
            image = "docker.io/b3log/siyuan";
            networks = [ quadlet.networks.${containers.networkName}.ref ];
            networkAliases = [ "siyuan" ];
            exec = [ "--workspace=/siyuan/workspace" ];
            environments = {
              RUN_IN_CONTAINER = "true";
              SIYUAN_ACCESS_AUTH_CODE_BYPASS = "true";
              TZ = "UTC";
            };
            volumes = [ "${containers.dataRoot}/siyuan:/siyuan/workspace" ];
            autoUpdate = "registry";
          };
          serviceConfig = {
            Restart = "always";
            RestartSec = "10s";
          };
        };

        dot.caddy.routes.siyuan = {
          host = "notes.${host.domain}";
          upstreams = [ "siyuan:6806" ];
        };
      };
  };
}
