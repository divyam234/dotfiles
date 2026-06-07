
{ inputs, lib, ... }:
let
  systems = [ "x86_64-linux" "aarch64-linux" ];
  forAllSystems = lib.genAttrs systems;
in
{
  perSystem = { pkgs, system, ... }: {
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
        runtimeInputs = with pkgs; [ systemd ];
        text = builtins.readFile ../scripts/svc;
      };
    };
  };
}
