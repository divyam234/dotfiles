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
            default_pool_size = 20;
            pooler_mode = "transaction";
            passthrough_auth = "enabled_plain";
          };
          databases = [
            {
              name = "postgres";
              host = "postgres";
              port = 5432;
              database_name = "postgres";
              role = "primary";
            }
          ];
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
