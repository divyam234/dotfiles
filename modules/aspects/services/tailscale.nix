{ den, ... }:
{
  den.aspects.tailscale = {
    includes = [ den.aspects.sops ];

    nixos =
      {
        config,
        host,
        lib,
        pkgs,
        secrets,
        ...
      }:
      let
        cfg = {
          enable = true;
          package = pkgs.tailscale;
          ssh = true;
          hostname = config.networking.hostName or null;
          exitNode = false;
          advertiseRoutes = [ ];
          acceptRoutes = false;
          advertiseTags = [ "tag:nixos" ];
          acceptRisk = null;
          authSecret = secrets.tailscale.oauth_client_secret;
          ephemeral = false;
          preauthorized = true;
        }
        // (host.tailscale or { });
        authSecretPath = cfg.authSecret.path;
        boolString = value: if value then "true" else "false";
        joinComma = lib.concatStringsSep ",";
        upArgs =
          lib.optionals cfg.ssh [ "--ssh" ]
          ++ lib.optionals (cfg.hostname != null && cfg.hostname != "") [ "--hostname=${cfg.hostname}" ]
          ++ lib.optionals cfg.exitNode [ "--advertise-exit-node" ]
          ++ lib.optionals cfg.acceptRoutes [ "--accept-routes" ]
          ++ lib.optionals (cfg.advertiseRoutes != [ ]) [
            "--advertise-routes=${joinComma cfg.advertiseRoutes}"
          ]
          ++ lib.optionals (cfg.advertiseTags != [ ]) [ "--advertise-tags=${joinComma cfg.advertiseTags}" ]
          ++ lib.optionals (cfg.acceptRisk != null) [ "--accept-risk=${cfg.acceptRisk}" ];
        upArgsText = lib.concatMapStringsSep " " lib.escapeShellArg upArgs;
      in
      {
        config = lib.mkIf cfg.enable {
          assertions = [
            {
              assertion = !cfg.autoconnect || builtins.pathExists secrets.commonSopsFile;
              message = "Host ${host.name} enables Tailscale autoconnect but ${toString secrets.commonSopsFile} does not exist.";
            }
          ];

          services.tailscale = {
            enable = true;
            inherit (cfg) package;
            useRoutingFeatures = "server";
          };

          networking.firewall = {
            checkReversePath = "loose";
            trustedInterfaces = [ "tailscale0" ];
            allowedUDPPorts = [ 41641 ];
          };

          systemd.services.tailscale-autoconnect = lib.mkIf cfg.autoconnect {
            description = "Automatic connection to Tailscale";
            after = [
              "network-online.target"
              "tailscale.service"
            ];
            wants = [
              "network-online.target"
              "tailscale.service"
            ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
            script = ''
              if ${cfg.package}/bin/tailscale status --json | ${pkgs.jq}/bin/jq -e '.BackendState == "Running"' >/dev/null; then
                exit 0
              fi

              secret="$(${pkgs.coreutils}/bin/tr -d '[:space:]' < '${authSecretPath}')"

              ${cfg.package}/bin/tailscale up \
                --auth-key="$secret?ephemeral=${boolString cfg.ephemeral}&preauthorized=${boolString cfg.preauthorized}" \
                ${upArgsText}
            '';
          };
        };
      };
  };
}
