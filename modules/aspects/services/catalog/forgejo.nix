{ den, ... }:
{
  den.aspects.forgejo = {
    includes = [
      den.aspects.oci-service
      den.aspects.pgdog
    ];

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
        dot.oci.secrets.forgejo.enable = true;
        systemd.tmpfiles.rules = lib.dot.mkServiceDirRules [ "forgejo" ];

        virtualisation.quadlet.containers.forgejo = {
          autoStart = true;
          containerConfig = {
            image = "codeberg.org/forgejo/forgejo:15";
            networks = [ quadlet.networks.${lib.dot.containerNetwork}.ref ];
            environmentFiles = [ (lib.dot.containerEnvFile "forgejo") ];
            volumes = [
              "${lib.dot.containerDataDir "forgejo"}:/data:rw"
              # "/etc/localtime:/etc/localtime:ro"
            ];
          };
          unitConfig = {
            After = [ quadlet.containers.pgdog.ref ];
            Requires = [ quadlet.containers.pgdog.ref ];
          };
          serviceConfig = {
            Restart = "always";
            RestartSec = "10s";
          };
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
      };
  };
}
