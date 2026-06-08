{ den, ... }:
{
  den.aspects.forgejo = {
    includes = [
      den.aspects.oci-service
      den.aspects.postgres
    ];

    nixos =
      { lib, host, ... }:
      {
        systemd.tmpfiles.rules = lib.dot.mkServiceDirRules [ "forgejo" ];

        virtualisation.oci-containers.containers.forgejo = lib.dot.mkOci "forgejo" {
          image = "codeberg.org/forgejo/forgejo:14";
          environmentFiles = [ (lib.dot.containerEnvFile "forgejo") ];
          dependsOn = [ "postgres" ];
          volumes = [
            "${lib.dot.containerDataDir "forgejo"}:/data:rw"
            "/etc/localtime:/etc/localtime:ro"
          ];
        };

        dot.caddy.routes.forgejo = {
          host = "git.${host.domain}";
          upstreams = [ "forgejo:3000" ];
          cacheStatic = true;
          extraConfig = ''
            request_body {
              max_size 512MB
            }
          '';
        };

        systemd.services.podman-forgejo = lib.dot.mkContainerDeps "forgejo" [ "postgres" ];
      };
  };
}
