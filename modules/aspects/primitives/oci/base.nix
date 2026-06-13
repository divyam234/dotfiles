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
        config,
        ...
      }:
      let
        cfg = config.dot.containers;
        dataDirUsers = lib.unique (
          lib.filter (dirUser: dirUser != user.userName) (
            lib.mapAttrsToList (_name: dir: dir.user) cfg.dataDirs
          )
        );
        dataDirType = lib.types.submodule {
          options = {
            user = lib.mkOption {
              type = lib.types.str;
              default = user.userName;
              description = "Owner used for this service container data directory.";
            };

            group = lib.mkOption {
              type = lib.types.str;
              default = "users";
              description = "Group used for this service container data directory.";
            };

            mode = lib.mkOption {
              type = lib.types.str;
              default = "0750";
              description = "Mode used for this service container data directory.";
            };
          };
        };
      in
      {
        options.dot.containers = {
          dataRoot = lib.mkOption {
            type = lib.types.str;
            default = "/home/${user.userName}/.local/state/container-services";
            description = "Host directory root for persistent service container bind mounts.";
          };

          dataDirs = lib.mkOption {
            type = lib.types.attrsOf dataDirType;
            default = { };
            description = "Service container data directories created below dot.containers.dataRoot.";
          };

          networkName = lib.mkOption {
            type = lib.types.str;
            default = "svc";
            description = "Shared Podman network name for service containers.";
          };

          secretDir = lib.mkOption {
            type = lib.types.str;
            default = "/run/secrets/container-env";
            description = "Runtime directory for generated container environment files.";
          };
        };

        config = {
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
            "d ${cfg.dataRoot} 0750 ${user.userName} users -"
          ]
          ++ lib.concatMap (dirUser: [
            "a+ /home/${user.userName} - - - - u:${dirUser}:--x"
            "a+ ${cfg.dataRoot} - - - - u:${dirUser}:--x"
          ]) dataDirUsers
          ++ lib.mapAttrsToList (
            name: dir: "d ${cfg.dataRoot}/${name} ${dir.mode} ${dir.user} ${dir.group} -"
          ) cfg.dataDirs;
        };
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
