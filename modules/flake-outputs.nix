{
  self,
  lib,
  ...
}:
{
  perSystem =
    { pkgs, system, ... }:
    let
      svcFish = pkgs.writeText "svc.fish" (builtins.readFile ../scripts/svc);
      netcup = self.nixosConfigurations.netcup.config;
      laptop = self.nixosConfigurations.laptop.config;
      home = self.homeConfigurations."bhunter@laptop".config;
      expectedContainers = [
        "adguard-cli"
        "caddy"
        "camofox-browser"
        "codeforge-mcp"
        "databasus"
        "forgejo"
        "gluetun"
        "hermes"
        "pgdog"
        "postgres"
        "redis"
        "siyuan"
        "vaultwarden"
      ];
      containerNames = builtins.attrNames netcup.virtualisation.quadlet.containers;
      missingContainers = lib.filter (name: !(builtins.elem name containerNames)) expectedContainers;
      expectedTemplates = [
        "caddy.env"
        "codeforge-mcp.env"
        "forgejo.env"
        "gluetun.env"
        "postgres.env"
        "redis.env"
        "vaultwarden.env"
      ];
      templateNames = builtins.attrNames netcup.sops.templates;
      missingTemplates = lib.filter (name: !(builtins.elem name templateNames)) expectedTemplates;
      caddyfile = netcup.environment.etc."caddy/Caddyfile".text;
      netcupHome = netcup.home-manager.users.bhunter;
      openchamberService = netcupHome.systemd.user.services.openchamber;
      opencodeService = netcupHome.systemd.user.services.opencode;
      brSvcFirewall = netcup.networking.firewall.interfaces."br-svc";
      codeforgeVolumes = netcup.virtualisation.quadlet.containers.codeforge-mcp.containerConfig.volumes;
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

      packages.svc = pkgs.writeShellApplication {
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
          assert missingContainers == [ ];
          assert missingTemplates == [ ];
          assert netcup.networking.domain == "bhunter.tech";
          assert builtins.hasAttr "bhunter" netcup.home-manager.users;
          assert builtins.hasAttr "netcup" netcup.services.restic.backups;
          assert builtins.hasAttr "svc" netcup.virtualisation.quadlet.networks;
          assert netcup.users.users.bhunter.linger == true;
          assert builtins.elem 39173 brSvcFirewall.allowedTCPPorts;
          assert builtins.elem 53 brSvcFirewall.allowedUDPPorts;
          assert builtins.hasAttr "openchamber" netcupHome.systemd.user.services;
          assert builtins.hasAttr "opencode" netcupHome.systemd.user.services;
          assert lib.hasInfix "--port 39173" (lib.concatStringsSep " " openchamberService.Service.ExecStart);
          assert lib.hasInfix "--port 4095" (lib.concatStringsSep " " opencodeService.Service.ExecStart);
          assert builtins.elem "/home/bhunter/repos/github:/workspace" codeforgeVolumes;
          assert laptop.programs.noctalia-greeter.greeter-args == "--session niri --user bhunter";
          assert lib.hasInfix "ai.bhunter.tech" caddyfile;
          assert lib.hasInfix "git.bhunter.tech" caddyfile;
          assert lib.hasInfix "vault.bhunter.tech" caddyfile;
          assert home.home.username == "bhunter";
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
