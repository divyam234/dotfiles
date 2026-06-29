{ den, ... }:
{
  den.aspects.hermes = { user, ... }: {
    nixos =
      {
        config,
        containers,
        pkgs,
        ...
      }:
      let
        quadlet = config.virtualisation.quadlet;
      in
      {
        virtualisation.quadlet.containers.hermes = {
          autoStart = false;
          containerConfig = {
            name = "hermes";
            image = "docker.io/nousresearch/hermes-agent:latest";
            networks = [ quadlet.networks.${containers.networkName}.ref ];
            networkAliases = [ "hermes" ];
            exec = [
              "gateway"
              "run"
            ];
            environments = {
              HERMES_DASHBOARD = "1";
              HERMES_DASHBOARD_TUI = "1";
              HERMES_DASHBOARD_INSECURE = "1";
              HERMES_GATEWAY_NO_SUPERVISE = "1";
              CAMOFOX_URL = "http://camofox-browser:9377";
            };
            memory = "4g";
            autoUpdate = "registry";
            podmanArgs = [ "--cpus=2.0" ];
            volumes = [ "${containers.dataRoot}/hermes:/opt/data" ];
          };
          unitConfig = {
            After = [ quadlet.containers.camofox-browser.ref ];
            Requires = [ quadlet.containers.camofox-browser.ref ];
          };
          serviceConfig = {
            ExecStartPre = pkgs.writeShellScript "hermes-pre-start" ''
              ${pkgs.coreutils}/bin/install -d -m 0750 -o ${user.userName} -g users ${containers.dataRoot}/hermes
              if [ ! -f ${containers.dataRoot}/hermes/config.yaml ]; then
                cat > ${containers.dataRoot}/hermes/config.yaml << 'EOF'
              browser:
                camofox:
                  managed_persistence: true
              EOF
                ${pkgs.coreutils}/bin/chown ${user.userName}:users ${containers.dataRoot}/hermes/config.yaml
                ${pkgs.coreutils}/bin/chmod 644 ${containers.dataRoot}/hermes/config.yaml
              fi
            '';
            Restart = "always";
            RestartSec = "10s";
            NoNewPrivileges = true;
          };
        };

      };
  };
}
