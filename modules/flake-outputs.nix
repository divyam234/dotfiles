{ inputs, lib, ... }:
let
  systems = [
    "x86_64-linux"
    "aarch64-linux"
  ];
  forAllSystems = lib.genAttrs systems;
in
{
  perSystem =
    { pkgs, system, ... }:
    let
      svcFish = pkgs.writeText "svc.fish" (builtins.readFile ../scripts/svc);
    in
    {
      formatter = pkgs.nixfmt;

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
    };
}
