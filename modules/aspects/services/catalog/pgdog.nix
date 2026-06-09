{ den, ... }:
{
  den.aspects.pgdog = {
    includes = [
      den.aspects.oci-service
      den.aspects.postgres
    ];
    nixos =
      { pkgs, lib, ... }:
      let
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

        virtualisation.oci-containers.containers.pgdog = lib.dot.mkOci "pgdog" {
          image = "ghcr.io/pgdogdev/pgdog";
          dependsOn = [ "postgres" ];
          volumes = [ "/etc/pgdog/pgdog.toml:/pgdog/pgdog.toml:ro" ];
        };

        systemd.services.podman-pgdog = lib.dot.mkContainerDeps "pgdog" [ "postgres" ];
      };
  };
}
