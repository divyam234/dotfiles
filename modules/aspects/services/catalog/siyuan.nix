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
      in
      {
        systemd.tmpfiles.rules = lib.dot.mkServiceDirRules [ "siyuan" ];
        virtualisation.quadlet.containers.siyuan = {
          autoStart = true;
          containerConfig = {
            image = "b3log/siyuan";
            networks = [ quadlet.networks.${lib.dot.containerNetwork}.ref ];
            exec = [ "--workspace=/siyuan/workspace" ];
            environments = {
              RUN_IN_CONTAINER = "true";
              SIYUAN_ACCESS_AUTH_CODE_BYPASS = "true";
              TZ = "UTC";
            };
            volumes = [ "${lib.dot.containerDataDir "siyuan"}:/siyuan/workspace" ];
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
