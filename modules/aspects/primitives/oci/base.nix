{ den, ... }:
let
  cleanup =
    pkgs:
    pkgs.writeShellApplication {
      name = "podman-cleanup";
      runtimeInputs = with pkgs; [
        podman
        buildah
      ];
      text = ''
        # Explicit paths keep Buildah in the same store as Podman, including
        # rootless storage on hosts whose Buildah defaults point at /var/lib.
        graph_root=$(podman info --format '{{.Store.GraphRoot}}')
        run_root=$(podman info --format '{{.Store.RunRoot}}')
        if (( EUID == 0 )); then
          buildah --root "$graph_root" --runroot "$run_root" rm --all
        else
          podman unshare buildah --root "$graph_root" --runroot "$run_root" rm --all
        fi
        podman container prune --force --filter until=168h
        podman image prune --all --force --filter until=168h
        # Deliberately includes named volumes: all unreferenced data is deleted.
        podman volume prune --force
      '';
    };
in
{
  den.aspects = {
    oci-service = {
      includes = [
        den.aspects.oci-base
        den.aspects.container-network
        den.aspects.container-auto-update
      ];
    };

    oci-runtime = { user, ... }: {
      nixos = { pkgs, ... }: {
        virtualisation = {
          containers.enable = true;
          podman = {
            enable = true;
            dockerCompat = true;
            defaultNetwork.settings.dns_enabled = true;
            autoPrune.enable = false;
          };
          quadlet.enable = true;
        };

        users.groups.podman = { };
        users.users.${user.userName}.extraGroups = [ "podman" ];

        # Disable the legacy units explicitly: autoPrune=false leaves empty
        # unit definitions in the current NixOS Podman module.
        systemd.services.podman-prune.enable = false;
        systemd.timers.podman-prune.enable = false;

        systemd.services.podman-cleanup = {
          description = "Clean unused root-owned container storage";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${cleanup pkgs}/bin/podman-cleanup";
            Nice = 19;
            IOSchedulingClass = "idle";
          };
        };
        systemd.timers.podman-cleanup = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "Sun *-*-* 04:00:00";
            RandomizedDelaySec = "45m";
            AccuracySec = "1m";
            # Do not run destructive catch-up cleanup outside the night window.
            Persistent = false;
          };
        };
      };

      homeManager =
        { pkgs, ... }:
        {
          home.packages = with pkgs; [
            local.svc
            podman
            podman-compose
            podman-tui
            dive
            skopeo
          ];

          systemd.user.services.podman-cleanup = {
            Unit.Description = "Clean unused rootless container storage";
            Service = {
              Type = "oneshot";
              ExecStart = "${cleanup pkgs}/bin/podman-cleanup";
              Nice = 19;
              IOSchedulingClass = "idle";
            };
          };
          systemd.user.timers.podman-cleanup = {
            Install.WantedBy = [ "timers.target" ];
            Timer = {
              OnCalendar = "Sun *-*-* 04:00:00";
              RandomizedDelaySec = "45m";
              AccuracySec = "1m";
              Persistent = false;
            };
          };
        };
    };

    oci-base = {
      includes = [ den.aspects.oci-runtime ];

      nixos =
        {
          config,
          containers,
          lib,
          ...
        }:
        let
          rootConfig = config;
          secretValue = lib.types.coercedTo (lib.types.addCheck lib.types.attrs (
            value: value.__secret or false
          )) toString (lib.types.addCheck lib.types.singleLineStr (value: !lib.hasInfix "\r" value));
          secretContainers = lib.filterAttrs (
            _: container: container.secretEnvironment != { }
          ) config.virtualisation.quadlet.containers;
        in
        {
          options.virtualisation.quadlet.containers = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule (
                { name, config, ... }: {
                  options.secretEnvironment = lib.mkOption {
                    # Template names must not force placeholders: SOPS itself
                    # enables placeholders only once a template exists.
                    type = lib.types.lazyAttrsOf secretValue;
                    default = { };
                    description = ''
                      Single-line secret environment values, including catalog secret
                      objects and strings containing SOPS placeholders. Generates a
                      private env file and restarts this container when it changes
                      during SOPS activation. Keep catalog declarations in nixosSecrets.
                    '';
                  };
                  config = {
                    autoStart = lib.mkDefault true;
                    containerConfig = {
                      name = lib.mkDefault name;
                      networks = lib.mkDefault [
                        rootConfig.virtualisation.quadlet.networks.${containers.networkName}.ref
                      ];
                      autoUpdate = lib.mkDefault "registry";
                      stopTimeout = lib.mkDefault 60;
                      environmentFiles = lib.mkIf (config.secretEnvironment != { }) [
                        rootConfig.sops.templates."${name}.env".path
                      ];
                    };
                    serviceConfig = {
                      Restart = lib.mkDefault "always";
                      RestartSec = lib.mkDefault "10s";
                      NoNewPrivileges = lib.mkDefault true;
                      TimeoutStopSec = lib.mkDefault "70s";
                    };
                    unitConfig = lib.mkIf (config.secretEnvironment != { } && rootConfig.sops.useSystemdActivation) {
                      After = [ "sops-install-secrets.service" ];
                      Requires = [ "sops-install-secrets.service" ];
                    };
                  };
                }
              )
            );
          };

          config = {
            assertions = lib.mapAttrsToList (name: container: {
              assertion = lib.all (
                key:
                builtins.match "[A-Za-z_][A-Za-z0-9_]*" key != null
                && !(builtins.hasAttr key container.containerConfig.environments)
              ) (builtins.attrNames container.secretEnvironment);
              message = "Quadlet ${name}: secretEnvironment keys must be valid environment names and must not also appear in containerConfig.environments.";
            }) secretContainers;

            sops.templates = lib.mapAttrs' (
              name: container:
              lib.nameValuePair "${name}.env" {
                path = "${containers.secretDir}/${name}.env";
                mode = "0400";
                content =
                  lib.concatStringsSep "\n" (
                    lib.mapAttrsToList (key: value: "${key}=${value}") container.secretEnvironment
                  )
                  + "\n";
                restartUnits = [ "${name}.service" ];
              }
            ) secretContainers;
          };
        };
    };

    container-auto-update = {
      nixos = _: {
        systemd.services.podman-auto-update = {
          description = "Update registry-managed Quadlet containers";
        };

        systemd.timers.podman-auto-update = {
          description = "Daily Quadlet registry update check";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
            RandomizedDelaySec = "1h";
          };
        };
      };
    };
  };
}
