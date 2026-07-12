{
  self,
  inputs,
  lib,
  ...
}:
{
  perSystem =
    { pkgs, system, ... }:
    let
      mkInstallerIso =
        {
          name,
          diskoConfig,
        }:
        let
          targetSystem = self.nixosConfigurations.${name}.config.system.build.toplevel;
          installer = inputs.nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              (
                {
                  lib,
                  modulesPath,
                  pkgs,
                  ...
                }:
                let
                  disko = inputs.disko.packages.${pkgs.stdenv.hostPlatform.system}.default;
                  installSystem = pkgs.writeShellApplication {
                    name = "install-system";
                    runtimeInputs = [
                      disko
                      pkgs.coreutils
                      pkgs.nixos-install-tools
                      pkgs.util-linux
                    ];
                    text = ''
                      usage() {
                        echo "Usage: install-system (--key-device /dev/sdX1 | --key-file /path/to/age-key.txt)" >&2
                        exit 1
                      }

                      if [ "$EUID" -ne 0 ]; then
                        echo "Run: sudo install-system --key-device /dev/sdX1" >&2
                        exit 1
                      fi

                      keyFile=""
                      mountDir=""
                      cleanup() {
                        if [ -n "$mountDir" ]; then
                          umount "$mountDir" 2>/dev/null || true
                          rmdir "$mountDir"
                        fi
                      }
                      trap cleanup EXIT

                      case "$1" in
                        --key-device)
                          [ "$#" -eq 2 ] || usage
                          mountDir="$(mktemp -d)"
                          mount -o ro "$2" "$mountDir"
                          keyFile="$mountDir/age-key.txt"
                          ;;
                        --key-file)
                          [ "$#" -eq 2 ] || usage
                          keyFile="$2"
                          ;;
                        *) usage ;;
                      esac

                      [ -f "$keyFile" ] || {
                        echo "No age-key.txt found at $keyFile" >&2
                        exit 1
                      }

                      disko --mode disko /etc/installer/disko.nix

                      install -d -m 0750 -o 0 -g 100 /mnt/var/lib/sops-nix
                      install -m 0640 -o 0 -g 100 "$keyFile" /mnt/var/lib/sops-nix/key.txt

                      nixos-install --system /etc/installer-system --no-root-passwd
                    '';
                  };
                in
                {
                  imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];

                  environment.etc = {
                    "installer/disko.nix".source = diskoConfig;
                    "installer-system".source = targetSystem;
                  };
                  environment.systemPackages = [ installSystem ];
                  image.baseName = lib.mkForce "${name}-installer";
                  isoImage = {
                    volumeID = "${lib.toUpper name}_INSTALLER";
                    storeContents = [ targetSystem ];
                  };
                }
              )
            ];
          };
        in
        installer.config.system.build.isoImage;
      netcup = self.nixosConfigurations.netcup.config;
      homelab = self.nixosConfigurations.homelab.config;
      laptop = self.nixosConfigurations.laptop.config;
      home = self.homeConfigurations."bhunter@laptop".config;
      contracts = {
        containers = import ../lib/checks/containers.nix { inherit lib netcup; };
        homelab = import ../lib/checks/homelab.nix { inherit homelab lib; };
        laptop = import ../lib/checks/laptop.nix { inherit home laptop; };
        netcup = import ../lib/checks/netcup.nix { inherit lib netcup; };
        openchamber = import ../lib/checks/openchamber.nix { inherit lib netcup; };
        secrets = import ../lib/checks/secrets.nix {
          inherit
            home
            homelab
            laptop
            netcup
            ;
        };
      };
    in
    {
      packages = lib.optionalAttrs (system == "x86_64-linux") {
        homelab-installer-iso = mkInstallerIso {
          name = "homelab";
          diskoConfig = ../hosts/homelab/disko.nix;
        };
        laptop-installer-iso = mkInstallerIso {
          name = "laptop";
          diskoConfig = ../hosts/laptop/disko.nix;
        };
      };

      formatter = pkgs.writeShellApplication {
        name = "dotfiles-fmt";
        runtimeInputs = with pkgs; [
          git
          nixfmt
        ];
        text = ''
          git ls-files '*.nix' -z \
            | while IFS= read -r -d ''' file; do
                if [ -e "$file" ]; then
                  printf '%s\0' "$file"
                fi
              done \
            | xargs -0 --no-run-if-empty nixfmt
        '';
      };

      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          age
          deadnix
          disko
          git
          go-task
          home-manager
          just
          nh
          nil
          nix-output-monitor
          nixfmt
          sops
          statix
        ];
      };

      checks = {
        formatter = pkgs.runCommand "dotfiles-format-check" { nativeBuildInputs = [ pkgs.nixfmt ]; } ''
          cp -r ${../.} source
          chmod -R u+w source
          cd source
          find . -name '*.nix' -print0 | xargs -0 nixfmt --check
          touch $out
        '';

        deadnix = pkgs.runCommand "dotfiles-deadnix" { nativeBuildInputs = [ pkgs.deadnix ]; } ''
          deadnix --no-lambda-pattern-names --fail ${../.}
          touch $out
        '';

        statix = pkgs.runCommand "dotfiles-statix" { nativeBuildInputs = [ pkgs.statix ]; } ''
          statix check ${../.}
          touch $out
        '';

        architecture = pkgs.runCommand "dotfiles-den-architecture" { } ''
          test ! -e ${../.}/registry
          test ! -e ${../.}/lib/registry
          test ! -e ${../.}/inventory
          test ! -e ${./core}/dispatch.nix
          test ! -e ${./core}/entities.nix
          test ! -e ${./core}/composition.nix
          ! grep -R --include='*.nix' -E '__scopeHandlers|constantHandler|resolveHost|homeManagerMode' \
            ${../hosts} ${../lib} ${./aspects} ${./core} ${./entities}
          touch $out
        '';

        composition-contract =
          assert lib.all (contract: contract) (builtins.attrValues contracts);
          pkgs.runCommand "dotfiles-composition-contract" { } ''
            touch $out
          '';
      }
      // lib.optionalAttrs (system == "x86_64-linux") {
        homelab-nixos-eval = self.nixosConfigurations.homelab.config.system.build.toplevel;
        laptop-nixos-eval = self.nixosConfigurations.laptop.config.system.build.toplevel;
        laptop-hm-eval = self.homeConfigurations."bhunter@laptop".activationPackage;
      }
      // lib.optionalAttrs (system == "aarch64-linux") {
        netcup-nixos-eval = self.nixosConfigurations.netcup.config.system.build.toplevel;
      };
    };
}
