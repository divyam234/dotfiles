{ den, ... }:
{
  den.aspects = {
    oci-service = {
      includes = [
        den.aspects.oci-base
        den.aspects.container-network
        den.aspects.container-update-webhook
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
        { lib, ... }:
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

          config = { };
        };
    };

    container-update-webhook = {
      nixos =
        { pkgs, ... }:
        let
          port = 9080;
          trigger = pkgs.writeShellScript "trigger-container-update" ''
            exec ${pkgs.systemd}/bin/systemctl --no-block start podman-auto-update.service
          '';
          hooks = pkgs.writeText "container-update-hooks.json" (
            builtins.toJSON [
              {
                id = "container-update";
                execute-command = trigger;
                response-message = "Container update queued\n";
              }
            ]
          );
        in
        {
          systemd.services = {
            podman-auto-update = {
              description = "Update registry-managed Quadlet containers";
              serviceConfig = {
                Type = "oneshot";
                ExecStart = "${pkgs.podman}/bin/podman auto-update";
              };
            };

            container-update-webhook = {
              description = "Tailscale-only container update webhook";
              after = [ "tailscale-autoconnect.service" ];
              wants = [ "tailscale-autoconnect.service" ];
              wantedBy = [ "multi-user.target" ];
              serviceConfig = {
                ExecStart = "${pkgs.webhook}/bin/webhook -hooks ${hooks} -http-methods POST -port ${toString port} -verbose";
                Restart = "on-failure";
                NoNewPrivileges = true;
                PrivateDevices = true;
                PrivateTmp = true;
                ProtectHome = true;
                ProtectSystem = "strict";
                ProtectKernelLogs = true;
                ProtectKernelModules = true;
                ProtectKernelTunables = true;
                ProtectControlGroups = true;
                RestrictAddressFamilies = [
                  "AF_INET"
                  "AF_INET6"
                  "AF_UNIX"
                ];
                IPAddressDeny = "any";
                IPAddressAllow = [
                  "127.0.0.0/8"
                  "::1/128"
                  "100.64.0.0/10"
                  "fd7a:115c:a1e0::/48"
                ];
              };
            };
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
