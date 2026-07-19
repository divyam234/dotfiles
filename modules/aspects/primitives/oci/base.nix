{ den, ... }:
{
  den.aspects = {
    oci-service = {
      includes = [
        den.aspects.oci-base
        den.aspects.container-network
        den.aspects.sops
      ];
    };

    oci-runtime = {
      nixos =
        { host, ... }:
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
          users.users.${host.user}.extraGroups = [ "podman" ];
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
        };
    };

    oci-base = {
      includes = [ den.aspects.oci-runtime ];

      nixos =
        { lib, pkgs, ... }:
        let
          cfg = {
            autoUpdate = {
              enable = false;
              calendar = "daily";
            };
          };
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
            systemd = {
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
