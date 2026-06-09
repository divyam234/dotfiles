{ den, ... }:
{
  den.aspects.postgres = {
    includes = [ den.aspects.oci-service ];
    nixos =
      { lib, ... }:
      {
        dot.oci.secrets.postgres.enable = true;
        systemd.tmpfiles.rules = lib.dot.mkServiceDirRules [ "postgres" ];
        virtualisation.oci-containers.containers.postgres = lib.dot.mkOci "postgres" {
          image = "ghcr.io/tgdrive/postgres:18";
          environmentFiles = [ (lib.dot.containerEnvFile "postgres") ];
          volumes = [ "${lib.dot.containerDataDir "postgres"}:/var/lib/postgresql" ];
        };
        systemd.services.podman-postgres = lib.dot.mkContainerSecretDeps "postgres" [ ];
      };
  };
}
