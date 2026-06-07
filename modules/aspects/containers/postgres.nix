{ den, ... }:
{
  den.aspects.postgres = {
    includes = [ den.aspects.oci-base den.aspects.container-network den.aspects.container-secrets ];
    nixos = { lib, ... }: {
      systemd.tmpfiles.rules = lib.dot.mkServiceDirRules [ "postgres" ];
      virtualisation.oci-containers.containers.postgres = lib.dot.mkOci "postgres" {
        image = "ghcr.io/tgdrive/postgres:18";
        environmentFiles = [ (lib.dot.containerEnvFile "postgres") ];
        volumes = [ "${lib.dot.containerDataDir "postgres"}:/var/lib/postgresql" ];
      };
      systemd.services.podman-postgres = lib.dot.mkContainerDeps "postgres";
    };
  };
}
