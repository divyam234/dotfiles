{ inputs, den, ... }:
{
  flake-file.inputs.nordvpn-nix = {
    url = "github:Triforcey/nordvpn-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.nordvpn = {
    includes = [ den.aspects.sops ];

    nixos =
      { user, ... }:
      {
        imports = [ inputs.nordvpn-nix.nixosModules.nordvpn ];
        services.nordvpn = {
          enable = true;
          openFirewall = false;
          users = [ user.userName ];
          gui.enable = false;
        };
      };

    homeManager =
      {
        config,
        pkgs,
        lib,
        secrets,
        ...
      }:
      {
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

              token_path="${secrets.nordvpn.token.path}"

              if ! nordvpn account >/dev/null 2>&1; then
                if [ -n "$token_path" ] && [ -f "$token_path" ]; then
                  echo "Logging in to NordVPN..."
                  nordvpn login --token "$(${pkgs.coreutils}/bin/tr -d '[:space:]' < "$token_path")"
                else
                  echo "No NordVPN token found, skipping login."
                fi
              else
                echo "Already logged in to NordVPN."
              fi

              if nordvpn settings 2>/dev/null | grep -q "LAN Discovery: enabled"; then
                echo "NordVPN settings already applied, skipping."
                exit 0
              fi

              nordvpn set analytics off || true

              nordvpn allowlist add subnet 100.64.0.0/10 || true
              nordvpn allowlist add port 41641 || true

              nordvpn set lan-discovery on
            '';
          };
          Install = {
            WantedBy = [ "default.target" ];
          };
        };
      };
  };
}
