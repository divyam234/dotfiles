{ den, ... }:
{
  den.aspects.valkey = {
    includes = [ den.aspects.oci-base den.aspects.container-network den.aspects.container-secrets ];
    nixos = { lib, ... }: {
      systemd.tmpfiles.rules = lib.dot.mkServiceDirRules [ "valkey" ];
      virtualisation.oci-containers.containers.valkey = lib.dot.mkOci "valkey" {
        image = "valkey/valkey:8-alpine";
        environmentFiles = [ (lib.dot.containerEnvFile "valkey") ];
        cmd = [ "sh" "-c" "valkey-server --appendonly yes --requirepass \"$VALKEY_PASSWORD\"" ];
        volumes = [ "${lib.dot.containerDataDir "valkey"}:/data" ];
      };
      systemd.services.podman-valkey = lib.dot.mkContainerDeps "valkey";
    };
  };
}
