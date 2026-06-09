{ den, ... }:
{
  den.aspects.pgdog = {
    includes = [
      den.aspects.oci-service
      den.aspects.postgres
    ];
    nixos =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      let
        quadlet = config.virtualisation.quadlet;
        toml = pkgs.formats.toml { };
        pgdogConfig = {
          general = {
            host = "0.0.0.0";
            port = 6432;
          };
          users.proxy.password = "proxy";
          pools."main" = {
            mode = "transaction";
            user = "proxy";
            database = "postgres";
            server = [
              {
                host = "postgres";
                port = 5432;
              }
            ];
          };
        };
      in
      {
        environment.etc."pgdog/pgdog.toml".text = builtins.readFile (
          toml.generate "pgdog.toml" pgdogConfig
        );

        systemd.tmpfiles.rules = lib.dot.mkServiceDirRules [ "pgdog" ];

        virtualisation.quadlet.containers.pgdog = {
          autoStart = true;
          containerConfig = {
            image = "ghcr.io/pgdogdev/pgdog";
            networks = [ quadlet.networks.${lib.dot.containerNetwork}.ref ];
            volumes = [ "/etc/pgdog/pgdog.toml:/pgdog/pgdog.toml:ro" ];
          };
          unitConfig = {
            After = [ quadlet.containers.postgres.ref ];
            Requires = [ quadlet.containers.postgres.ref ];
          };
          serviceConfig = {
            Restart = "always";
            RestartSec = "10s";
          };
        };
      };
  };
}
