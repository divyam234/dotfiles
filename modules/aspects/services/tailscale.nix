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
        ...
      }:
      let
        cfg = config.dot.tailscale;
        inherit (host) secretsFile;
        authSecretPath = config.sops.secrets.${cfg.authSecret}.path;
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
        options.dot.tailscale = {
          enable = lib.mkEnableOption "Tailscale" // {
            default = true;
          };
          package = lib.mkPackageOption pkgs "tailscale" { };
          ssh = lib.mkOption {
            description = "Enable Tailscale SSH.";
            type = lib.types.bool;
            default = true;
          };
          hostname = lib.mkOption {
            description = "Machine name to advertise to Tailscale.";
            type = lib.types.nullOr lib.types.str;
            default = config.networking.hostName or null;
          };
          exitNode = lib.mkOption {
            description = "Advertise this machine as a Tailscale exit node.";
            type = lib.types.bool;
            default = false;
          };
          advertiseRoutes = lib.mkOption {
            description = "Routes to advertise to the tailnet.";
            type = lib.types.listOf lib.types.str;
            default = [ ];
            example = [ "192.168.1.0/24" ];
          };
          acceptRoutes = lib.mkOption {
            description = "Accept routes advertised by other tailnet nodes.";
            type = lib.types.bool;
            default = false;
          };
          advertiseTags = lib.mkOption {
            description = "Tags to advertise when authenticating.";
            type = lib.types.listOf lib.types.str;
            default = [ "tag:nixos" ];
          };
          acceptRisk = lib.mkOption {
            description = "Risk acknowledgement passed to tailscale up.";
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
          autoconnect = lib.mkOption {
            description = "Authenticate automatically using the configured SOPS OAuth client secret.";
            type = lib.types.bool;
            default = false;
          };
          authSecret = lib.mkOption {
            description = "SOPS secret key containing the Tailscale OAuth client secret.";
            type = lib.types.str;
            default = "tailscale/oauth_client_secret";
          };
          ephemeral = lib.mkOption {
            description = "Whether OAuth-authenticated nodes should be ephemeral.";
            type = lib.types.bool;
            default = false;
          };
          preauthorized = lib.mkOption {
            description = "Whether OAuth-authenticated nodes should be preauthorized.";
            type = lib.types.bool;
            default = true;
          };
        };

        config = lib.mkIf cfg.enable {
          assertions = [
            {
              assertion = !cfg.autoconnect || secretsFile != null;
              message = "Host ${host.name} enables Tailscale autoconnect but does not set host.secretsFile.";
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

          sops.secrets = lib.mkIf (cfg.autoconnect && secretsFile != null) {
            ${cfg.authSecret}.sopsFile = secretsFile;
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
