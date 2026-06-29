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
      rustPkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [ inputs.rust-overlay.overlays.default ];
      };
      rustToolchain = rustPkgs.rust-bin.stable.latest.default;
      rustPlatform = rustPkgs.makeRustPlatform {
        cargo = rustToolchain;
        rustc = rustToolchain;
      };
      netcup = self.nixosConfigurations.netcup.config;
      laptop = self.nixosConfigurations.laptop.config;
      home = self.homeConfigurations."bhunter@laptop".config;
      contracts = {
        containers = import ../lib/checks/containers.nix { inherit lib netcup; };
        laptop = import ../lib/checks/laptop.nix { inherit home laptop; };
        netcup = import ../lib/checks/netcup.nix { inherit lib netcup; };
        openchamber = import ../lib/checks/openchamber.nix { inherit lib netcup; };
        secrets = import ../lib/checks/secrets.nix { inherit home laptop netcup; };
      };
    in
    {
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
          rustToolchain
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

      packages.svc = rustPlatform.buildRustPackage {
        pname = "svc";
        version = "0.1.0";
        src = lib.cleanSourceWith {
          src = ../tools/svc;
          filter = path: _type: baseNameOf path != "target";
        };

        cargoLock.lockFile = ../tools/svc/Cargo.lock;

        nativeBuildInputs = [ pkgs.makeWrapper ];
        postInstall = ''
          wrapProgram $out/bin/svc \
            --prefix PATH : ${
              lib.makeBinPath (
                with pkgs;
                [
                  podman
                  systemd
                ]
              )
            }
        '';
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
        laptop-nixos-eval = self.nixosConfigurations.laptop.config.system.build.toplevel;
        laptop-hm-eval = self.homeConfigurations."bhunter@laptop".activationPackage;
      }
      // lib.optionalAttrs (system == "aarch64-linux") {
        netcup-nixos-eval = self.nixosConfigurations.netcup.config.system.build.toplevel;
      };
    };
}
