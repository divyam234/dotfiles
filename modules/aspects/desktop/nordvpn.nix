{ den, ... }:
{
  den.aspects.nordvpn = {
    includes = [ den.aspects.sops ];

    nixos =
      { host, pkgs, ... }:
      {
        users = {
          groups.nordvpn = { };
          users.${host.user}.extraGroups = [ "nordvpn" ];
        };

        networking.firewall = {
          checkReversePath = "loose";
          allowedUDPPorts = [ 1194 ];
          allowedTCPPorts = [ 443 ];
        };

        systemd = {
          sockets.nordvpnd = {
            description = "NordVPN Daemon Socket";
            wantedBy = [ "sockets.target" ];
            bindsTo = [ "nordvpnd.service" ];

            socketConfig = {
              ListenStream = "/run/nordvpn/nordvpnd.sock";
              SocketGroup = "nordvpn";
              SocketMode = "0660";
              DirectoryMode = "0750";
              RemoveOnStop = true;
            };
          };

          services.nordvpnd = {
            description = "NordVPN Daemon";
            wantedBy = [ "multi-user.target" ];
            requires = [ "nordvpnd.socket" ];
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];

            serviceConfig = {
              ExecStart = "${pkgs.nordvpn}/bin/nordvpnd";
              NonBlocking = true;
              KillMode = "process";
              Restart = "always";
              RestartSec = 5;
              RuntimeDirectory = "nordvpn";
              RuntimeDirectoryMode = "0750";
              RuntimeDirectoryPreserve = true;
              Group = "nordvpn";
            };
          };
        };
      };

    homeManager =
      {
        pkgs,
        secrets,
        ...
      }:
      {
        home.packages = [ pkgs.nordvpn ];

        systemd.user.services.nordvpn-setup = {
          Unit = {
            Description = "One-time NordVPN setup: login, settings, and Tailscale whitelist";
            After = [ "network.target" ];
            Wants = [ "network.target" ];
          };
          Service = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = pkgs.writeShellScript "nordvpn-setup" ''
              set -uo pipefail

              nordvpn="${pkgs.nordvpn}/bin/nordvpn"
              grep="${pkgs.gnugrep}/bin/grep"
              token_path="${secrets.nordvpn.token.path}"

              if ! "$nordvpn" account >/dev/null 2>&1; then
                if [ -n "$token_path" ] && [ -f "$token_path" ]; then
                  echo "Logging in to NordVPN..."
                  "$nordvpn" login --token "$(${pkgs.coreutils}/bin/tr -d '[:space:]' < "$token_path")"
                else
                  echo "No NordVPN token found, skipping login."
                fi
              else
                echo "Already logged in to NordVPN."
              fi

              if "$nordvpn" settings 2>/dev/null | "$grep" -q "LAN Discovery: enabled"; then
                echo "NordVPN settings already applied, skipping."
                exit 0
              fi

              "$nordvpn" set analytics off || true

              "$nordvpn" allowlist add subnet 100.64.0.0/10 || true
              "$nordvpn" allowlist add port 41641 || true

              "$nordvpn" set lan-discovery on
            '';
          };
          Install = {
            WantedBy = [ "default.target" ];
          };
        };
      };
  };
}
