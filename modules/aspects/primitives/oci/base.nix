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
        pathPrefixes =
          path:
          let
            parts = lib.filter (part: part != "") (lib.splitString "/" path);
            go =
              prefix: rest:
              if rest == [ ] then
                [ ]
              else
                let
                  next = "${prefix}/${builtins.head rest}";
                in
                [ next ] ++ go next (builtins.tail rest);
          in
          go "" parts;
        ownerType = lib.types.submodule {
          options = {
            user = lib.mkOption {
              type = lib.types.str;
              description = "Host UID or username used as a container data owner.";
            };

            group = lib.mkOption {
              type = lib.types.str;
              description = "Host GID or group name used as a container data group.";
            };
          };
        };
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
        dataRootPrefix = "${cfg.dataRoot}/";
        mountedDataDirs = lib.unique (
          lib.concatLists (
            lib.mapAttrsToList (
              _name: container:
              let
                volumes = container.containerConfig.volumes or [ ];
                hostPaths = map (volume: builtins.elemAt (lib.splitString ":" volume) 0) volumes;
                dataRootHostPaths = lib.filter (lib.hasPrefix dataRootPrefix) hostPaths;
              in
              map (
                hostPath: builtins.elemAt (lib.splitString "/" (lib.removePrefix dataRootPrefix hostPath)) 0
              ) dataRootHostPaths
            ) config.virtualisation.quadlet.containers
          )
        );
        missingDataDirs = lib.filter (name: !(builtins.hasAttr name cfg.dataDirs)) mountedDataDirs;
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

          owners = lib.mkOption {
            type = lib.types.attrsOf ownerType;
            default = {
              home = {
                user = user.userName;
                group = "users";
              };
              postgres = {
                user = "999";
                group = "999";
              };
              bitnami = {
                user = "1001";
                group = "0";
              };
            };
            description = "Semantic host ownership presets for service container data directories.";
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

          autoUpdate = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether to run podman auto-update for labelled containers.";
            };

            calendar = lib.mkOption {
              type = lib.types.str;
              default = "daily";
              description = "Systemd calendar expression for podman auto-update.";
            };
          };
        };

        config = {
          assertions = [
            {
              assertion = missingDataDirs == [ ];
              message = "Container dataRoot bind mounts are missing dot.containers.dataDirs entries: ${lib.concatStringsSep ", " missingDataDirs}";
            }
          ];

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
          ++ lib.concatMap (
            dirUser: map (path: "a+ ${path} - - - - u:${dirUser}:--x") (pathPrefixes cfg.dataRoot)
          ) dataDirUsers
          ++ lib.mapAttrsToList (
            name: dir: "d ${cfg.dataRoot}/${name} ${dir.mode} ${dir.user} ${dir.group} -"
          ) cfg.dataDirs;

          system.activationScripts.createContainerDataDirs = lib.concatStringsSep "\n" (
            [
              "${pkgs.coreutils}/bin/install -d -m 0750 -o ${user.userName} -g users ${cfg.dataRoot}"
            ]
            ++ lib.mapAttrsToList (
              name: dir:
              "${pkgs.coreutils}/bin/install -d -m ${dir.mode} -o ${dir.user} -g ${dir.group} ${cfg.dataRoot}/${name}"
            ) cfg.dataDirs
          );

          systemd.services.podman-auto-update = lib.mkIf cfg.autoUpdate.enable {
            description = "Podman auto-update containers";
            serviceConfig = {
              Type = "oneshot";
              ExecStart = "${pkgs.podman}/bin/podman auto-update";
            };
          };

          systemd.timers.podman-auto-update = lib.mkIf cfg.autoUpdate.enable {
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = cfg.autoUpdate.calendar;
              Persistent = true;
            };
          };
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
