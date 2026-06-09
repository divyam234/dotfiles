{ den, ... }:
{
  den.aspects.vaultwarden = {
    includes = [
      den.aspects.oci-service
      den.aspects.postgres
    ];

    nixos =
      { lib, host, ... }:
      {
        dot.oci.secrets.vaultwarden.enable = true;
        systemd.tmpfiles.rules = lib.dot.mkServiceDirRules [ "vaultwarden" ];

        virtualisation.oci-containers.containers.vaultwarden = lib.dot.mkOci "vaultwarden" {
          image = "vaultwarden/server:latest-alpine";
          environmentFiles = [ (lib.dot.containerEnvFile "vaultwarden") ];
          dependsOn = [ "postgres" ];
          volumes = [ "${lib.dot.containerDataDir "vaultwarden"}:/data" ];
        };

        dot.caddy.routes.vaultwarden = {
          host = "vault.${host.domain}";
          upstreams = [ "vaultwarden:80" ];
          cacheStatic = false;
          extraConfig = ''
            request_body {
              max_size 128MB
            }
          '';
        };

        systemd.services.podman-vaultwarden = lib.dot.mkContainerSecretDeps "vaultwarden" [ "postgres" ];
      };
  };
}
