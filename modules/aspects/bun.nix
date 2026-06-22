{ den, ... }:
{
  den.aspects.bun = {
    homeManager =
      {
        config,
        lib,
        pkgs,
        ...
      }:

      let
        cfg = config.programs.bunGlobalCli;

        packages = lib.unique cfg.packages;

        packagesText = builtins.concatStringsSep "\n" packages + lib.optionalString (packages != [ ]) "\n";

        packagesFile = pkgs.writeText "bun-global-cli-packages.txt" packagesText;

        syncScript = pkgs.writeShellScriptBin "bun-global-cli-sync" ''
          set -euo pipefail

          if ! ${pkgs.curl}/bin/curl -fsSL --max-time 5 "https://registry.npmjs.org" >/dev/null 2>&1; then
            echo "Network unavailable, skipping bun global CLI sync."
            exit 0
          fi

          export BUN_INSTALL="${config.home.homeDirectory}/.bun"
          export BUN_INSTALL_GLOBAL_DIR="${config.home.homeDirectory}/.bun/install/global"
          export BUN_INSTALL_BIN="${config.home.homeDirectory}/.bun/bin"
          export PATH="$BUN_INSTALL_BIN:${pkgs.bun}/bin:$PATH"

          mkdir -p "$BUN_INSTALL_BIN" "$BUN_INSTALL_GLOBAL_DIR"

          state_dir="${config.xdg.stateHome}/bun-global-cli"
          versions_file="$state_dir/versions"
          new_versions_file="$state_dir/versions.next"

          mkdir -p "$state_dir"
          touch "$versions_file"
          : > "$new_versions_file"

          encode_pkg_name() {
            printf '%s' "$1" | ${pkgs.gnused}/bin/sed 's/\//%2F/g'
          }

          parse_spec() {
            spec="$1"
            selector="latest"

            if [[ "$spec" == @* ]]; then
              # Scoped package:
              #   @scope/name
              #   @scope/name@latest
              #   @scope/name@1.2.3
              scope="''${spec%%/*}"
              rest="''${spec#*/}"

              if [[ "$rest" == *@* ]]; then
                pkg_name_part="''${rest%@*}"
                selector="''${rest##*@}"
                pkg="$scope/$pkg_name_part"
              else
                pkg="$spec"
              fi
            else
              # Unscoped package:
              #   prettier
              #   prettier@latest
              #   prettier@3.5.0
              if [[ "$spec" == *@* ]]; then
                pkg="''${spec%@*}"
                selector="''${spec##*@}"
              else
                pkg="$spec"
              fi
            fi
          }

          get_remote_version() {
            pkg="$1"
            selector="$2"

            # Exact pinned semver like 1.2.3, 1.2.3-beta.1, etc.
            if printf '%s' "$selector" | ${pkgs.gnugrep}/bin/grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+'; then
              printf '%s\n' "$selector"
              return 0
            fi

            encoded_pkg="$(encode_pkg_name "$pkg")"

            ${pkgs.curl}/bin/curl -fsSL "https://registry.npmjs.org/$encoded_pkg" \
              | ${pkgs.jq}/bin/jq -r --arg tag "$selector" '.["dist-tags"][$tag] // empty'
          }

          get_stored_version() {
            pkg="$1"

            ${pkgs.gnugrep}/bin/grep -F "$pkg " "$versions_file" \
              | ${pkgs.coreutils}/bin/tail -n 1 \
              | ${pkgs.gawk}/bin/awk '{print $2}' || true
          }

          changed=0

          while IFS= read -r spec; do
            [ -z "$spec" ] && continue

            parse_spec "$spec"

            remote_version="$(get_remote_version "$pkg" "$selector")"

            if [ -z "$remote_version" ]; then
              echo "Could not resolve npm version for: $spec"
              exit 1
            fi

            stored_version="$(get_stored_version "$pkg")"

            printf '%s %s %s\n' "$pkg" "$remote_version" "$selector" >> "$new_versions_file"

            if [ "$stored_version" != "$remote_version" ]; then
              echo "Updating $pkg: ''${stored_version:-none} -> $remote_version"
              ${pkgs.bun}/bin/bun add -g "$pkg@$remote_version"
              changed=1
            else
              echo "Already current: $pkg@$remote_version"
            fi
          done < "${packagesFile}"

          mv "$new_versions_file" "$versions_file"

          if [ "$changed" = 0 ]; then
            echo "All Bun global CLI packages are current."
          fi
        '';
      in
      {
        options.programs.bunGlobalCli = {
          enable = lib.mkEnableOption "global CLI tools installed through Bun";

          installBun = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether this module should add pkgs.bun to home.packages.";
          };

          packages = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            example = [
              "@openai/codex@latest"
              "@anthropic-ai/claude-code@latest"
              "@google/gemini-cli@latest"
              "@oh-my-pi/pi-coding-agent@latest"
            ];
            description = "Global CLI npm packages installed with bun add -g.";
          };

          timer.enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable a systemd user timer to refresh global Bun CLI packages.";
          };

          timer.calendar = lib.mkOption {
            type = lib.types.str;
            default = "weekly";
            example = "daily";
            description = "systemd OnCalendar value for automatic Bun CLI package refresh.";
          };
        };

        config = lib.mkIf cfg.enable {
          home = {
            packages = lib.optional cfg.installBun pkgs.bun ++ [
              syncScript
            ];

            sessionVariables = {
              BUN_INSTALL = "${config.home.homeDirectory}/.bun";
              BUN_INSTALL_GLOBAL_DIR = "${config.home.homeDirectory}/.bun/install/global";
              BUN_INSTALL_BIN = "${config.home.homeDirectory}/.bun/bin";
            };

            sessionPath = [
              "${config.home.homeDirectory}/.bun/bin"
            ];

            file.".config/bun/global-cli-packages.txt".source = packagesFile;

            shellAliases = {
              bun-cli-sync = "bun-global-cli-sync";
              bun-cli-list = "cat ~/.config/bun/global-cli-packages.txt";
              bun-cli-versions = "cat ${config.xdg.stateHome}/bun-global-cli/versions";
            };

            activation.syncBunGlobalCliPackages = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              ${syncScript}/bin/bun-global-cli-sync
            '';
          };

          systemd.user.services.bun-global-cli-sync = lib.mkIf cfg.timer.enable {
            Unit = {
              Description = "Sync global Bun CLI packages only when upstream version changes";
            };

            Service = {
              Type = "oneshot";
              ExecStart = "${syncScript}/bin/bun-global-cli-sync";
            };
          };

          systemd.user.timers.bun-global-cli-sync = lib.mkIf cfg.timer.enable {
            Unit = {
              Description = "Timer for global Bun CLI package version check";
            };

            Timer = {
              OnCalendar = cfg.timer.calendar;
              Persistent = true;
            };

            Install = {
              WantedBy = [ "timers.target" ];
            };
          };
        };
      };
  };
}
