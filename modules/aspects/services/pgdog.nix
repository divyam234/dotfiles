{ den, ... }:
{
  den.aspects.pgdog = {
    nixos =
      {
        config,
        containers,
        pkgs,
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
        pgdogConfigFile = toml.generate "pgdog.toml" pgdogConfig;
      in
      {
        virtualisation.quadlet.containers.pgdog = {
          autoStart = true;
          containerConfig = {
            name = "pgdog";
            image = "ghcr.io/pgdogdev/pgdog";
            networks = [ quadlet.networks.${containers.networkName}.ref ];
            networkAliases = [ "pgdog" ];
            volumes = [ "${pgdogConfigFile}:/pgdog/pgdog.toml:ro" ];
            autoUpdate = "registry";
          };
          unitConfig = {
            After = [ quadlet.containers.postgres.ref ];
            Requires = [ quadlet.containers.postgres.ref ];
          };
          serviceConfig = {
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
