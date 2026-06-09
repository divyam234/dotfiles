{ den, ... }:
{
  den.aspects.postgres = {
    includes = [ den.aspects.oci-service ];
    nixos =
      { config, lib, ... }:
      let
        quadlet = config.virtualisation.quadlet;
      in
      {
        dot.oci.secrets.postgres.enable = true;
        systemd.tmpfiles.rules = lib.dot.mkServiceDirRules [ "postgres" ];
        virtualisation.quadlet.containers.postgres = {
          autoStart = true;
          containerConfig = {
            image = "ghcr.io/tgdrive/postgres:18";
            networks = [ quadlet.networks.${lib.dot.containerNetwork}.ref ];
            environmentFiles = [ (lib.dot.containerEnvFile "postgres") ];
            volumes = [ "${lib.dot.containerDataDir "postgres"}:/var/lib/postgresql" ];
          };
          unitConfig = {
            After = [ "sops-install-secrets.service" ];
            Requires = [ "sops-install-secrets.service" ];
          };
          serviceConfig = {
            Restart = "always";
            RestartSec = "10s";
          };
        };
      };
  };
}
