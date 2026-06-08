{ den, ... }:
{
  den.aspects.siyuan = {
    includes = [ den.aspects.oci-service ];
    nixos =
      { lib, host, ... }:
      {
        systemd.tmpfiles.rules = lib.dot.mkServiceDirRules [ "siyuan" ];
        virtualisation.oci-containers.containers.siyuan = lib.dot.mkOci "siyuan" {
          image = "b3log/siyuan";
          cmd = [ "--workspace=/siyuan/workspace" ];
          environment = {
            RUN_IN_CONTAINER = "true";
            SIYUAN_ACCESS_AUTH_CODE_BYPASS = "true";
            TZ = "UTC";
          };
          volumes = [ "${lib.dot.containerDataDir "siyuan"}:/siyuan/workspace" ];
        };

        dot.caddy.routes.siyuan = {
          host = "notes.${host.domain}";
          upstreams = [ "siyuan:6806" ];
        };

        systemd.services.podman-siyuan = lib.dot.mkContainerDeps "siyuan" [ ];
      };
  };
}
