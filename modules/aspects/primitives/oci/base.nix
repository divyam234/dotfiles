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
        {
          options.virtualisation.quadlet.containers = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule (
                { name, ... }: {
                  config = {
                    autoStart = lib.mkDefault true;
                    containerConfig = {
                      name = lib.mkDefault name;
                      networks = lib.mkDefault [
                        config.virtualisation.quadlet.networks.${containers.networkName}.ref
                      ];
                      autoUpdate = lib.mkDefault "registry";
                      stopTimeout = lib.mkDefault 60;
                    };
                    serviceConfig = {
                      Restart = lib.mkDefault "always";
                      RestartSec = lib.mkDefault "10s";
                      NoNewPrivileges = lib.mkDefault true;
                      TimeoutStopSec = lib.mkDefault "70s";
                    };
                  };
                }
              )
            );
          };

          config = { };
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
