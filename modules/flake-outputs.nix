{
  self,
  inputs,
  lib,
  ...
}:
let
  registry = import ../registry;
  users = import ../inventory/users.nix;
  hosts = import ../inventory/hosts.nix;
  inherit ((import ../lib/registry/resolve.nix { inherit lib; })) resolveHost;
in
{
  flake.resolvedHosts = lib.mapAttrs (
    _name: host: resolveHost { inherit registry users host; }
  ) hosts;

  perSystem =
    { pkgs, system, ... }:
    let
      svcFish = pkgs.writeText "svc.fish" (builtins.readFile ../scripts/svc);
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

      packages = {
        svc = pkgs.writeShellApplication {
          name = "svc";
          runtimeInputs = with pkgs; [
            coreutils
            fish
            podman
            systemd
          ];
          text = ''
            exec fish ${svcFish} "$@"
          '';
        };
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

        registry-resolver = pkgs.runCommand "registry-resolver-tests" { } ''
          export NIX_STATE_DIR=$TMPDIR/nix-state
          mkdir -p "$NIX_STATE_DIR/profiles"
          ${pkgs.nix}/bin/nix-instantiate --eval --strict --expr 'import ${../tests/registry/resolve.nix} { lib = import ${inputs.nixpkgs}/lib; root = ${../.}; }' >/dev/null
          touch $out
        '';
      }
      // lib.optionalAttrs (system == "x86_64-linux") {
        laptop-nixos-eval = self.nixosConfigurations.laptop.config.system.build.toplevel;
        netcup-nixos-eval = self.nixosConfigurations.netcup.config.system.build.toplevel;
      };
    };
}
