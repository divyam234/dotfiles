{ den, ... }:
{
  den.aspects = {
    oci-service = {
      includes = [
        den.aspects.oci-base
        den.aspects.container-network
        den.aspects.container-secrets
      ];
    };

    oci-runtime = {
      nixos =
        { user, ... }:
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
        };
    };

    oci-base = {
      includes = [ den.aspects.oci-runtime ];

      nixos =
        {
          pkgs,
          user,
          lib,
          config,
          containerDataDirs,
          ...
        }:
        let
          rawDataDirs = lib.foldl' lib.recursiveUpdate { } containerDataDirs;
          homeDir = "/home/${user.userName}";
          xdgDataDir = "${homeDir}/.local";
          xdgStateDir = "${xdgDataDir}/state";
          normalizeDataDir =
            dir:
            {
              user = user.userName;
              group = "users";
              mode = "0750";
            }
            // dir;
          cfg = {
            dataRoot = "${xdgStateDir}/container-services";
            dataDirs = lib.mapAttrs (_name: normalizeDataDir) rawDataDirs;
            owners = {
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
            networkName = "svc";
            secretDir = "/run/secrets/container-env";
            autoUpdate = {
              enable = false;
              calendar = "daily";
            };
          };
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
          dataDirUsers = lib.unique (
            lib.filter (dirUser: dirUser != user.userName) (
              lib.mapAttrsToList (_name: dir: dir.user) cfg.dataDirs
            )
          );
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
          options.virtualisation.quadlet.containers = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule {
                config = {
                  containerConfig.stopTimeout = lib.mkDefault 60;
                  serviceConfig.TimeoutStopSec = lib.mkDefault "70s";
                };
              }
            );
          };

          config = {
            _module.args.containers = cfg;

            assertions = [
              {
                assertion = missingDataDirs == [ ];
                message = "Container dataRoot bind mounts are missing containerDataDirs quirk entries: ${lib.concatStringsSep ", " missingDataDirs}";
              }
            ];

            system.activationScripts.createContainerDataDirs = lib.concatStringsSep "\n" (
              [
                "${pkgs.coreutils}/bin/install -d -m 0700 -o ${user.userName} -g users ${xdgDataDir}"
                "${pkgs.coreutils}/bin/install -d -m 0700 -o ${user.userName} -g users ${xdgStateDir}"
                "${pkgs.coreutils}/bin/install -d -m 0750 -o ${user.userName} -g users ${cfg.dataRoot}"
              ]
              ++ lib.mapAttrsToList (
                name: dir:
                "${pkgs.coreutils}/bin/install -d -m ${dir.mode} -o ${dir.user} -g ${dir.group} ${cfg.dataRoot}/${name}"
              ) cfg.dataDirs
            );

            systemd = {
              tmpfiles.rules = [
                "d ${xdgDataDir} 0700 ${user.userName} users -"
                "d ${xdgStateDir} 0700 ${user.userName} users -"
                "d ${cfg.dataRoot} 0750 ${user.userName} users -"
              ]
              ++ lib.concatMap (
                dirUser: map (path: "a+ ${path} - - - - u:${dirUser}:--x") (pathPrefixes cfg.dataRoot)
              ) dataDirUsers
              ++ lib.mapAttrsToList (
                name: dir: "d ${cfg.dataRoot}/${name} ${dir.mode} ${dir.user} ${dir.group} -"
              ) cfg.dataDirs;

              services.podman-auto-update = lib.mkIf cfg.autoUpdate.enable {
                description = "Podman auto-update containers";
                serviceConfig = {
                  Type = "oneshot";
                  ExecStart = "${pkgs.podman}/bin/podman auto-update";
                };
              };

              timers.podman-auto-update = lib.mkIf cfg.autoUpdate.enable {
                wantedBy = [ "timers.target" ];
                timerConfig = {
                  OnCalendar = cfg.autoUpdate.calendar;
                  Persistent = true;
                };
              };
            };
          };
        };
    };
  };
}
