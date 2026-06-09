{ den, ... }:
{
  den.aspects.oci-service = {
    includes = [
      den.aspects.oci-base
      den.aspects.container-network
      den.aspects.container-secrets
    ];
  };

  den.aspects.oci-base = {
    nixos =
      {
        pkgs,
        user,
        lib,
        ...
      }:
      {
        virtualisation = {
          containers.enable = true;
          podman = {
            enable = true;
            dockerCompat = true;
            defaultNetwork.settings.dns_enabled = true;
            autoPrune = {
              enable = true;
              dates = "weekly";
              flags = [ "--all" ];
            };
          };
          quadlet.enable = true;
        };

        users.groups.podman = { };
        users.users.${user.userName}.extraGroups = [ "podman" ];

        systemd.tmpfiles.rules = [
          "d ${lib.dot.containerDataRoot} 0750 root root -"
          "d ${lib.dot.containerSecretDir} 0750 root root -"
        ];
      };

    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          podman
          podman-compose
          podman-tui
          dive
          skopeo
        ];

        home.sessionVariables = {
          DOCKER_HOST = "unix://%XDG_RUNTIME_DIR%/podman/podman.sock";
        };
      };
  };
}
