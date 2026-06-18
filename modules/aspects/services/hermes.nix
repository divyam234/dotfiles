{ den, ... }:
{
  den.aspects.hermes = { user, ... }: {
    includes = [ den.aspects.oci-service ];
    containerDataDirs.hermes = {
      user = user.userName;
      group = "users";
    };

    nixos =
      {
        config,
        containers,
        ...
      }:
      let
        quadlet = config.virtualisation.quadlet;
      in
      {
        # Seed hermes config on first boot
        system.activationScripts.seedHermesConfig = ''
          if [ ! -f ${containers.dataRoot}/hermes/config.yaml ]; then
            mkdir -p ${containers.dataRoot}/hermes
            cat > ${containers.dataRoot}/hermes/config.yaml << 'EOF'
          browser:
            camofox:
              managed_persistence: true
          EOF
            chmod 644 ${containers.dataRoot}/hermes/config.yaml
          fi
        '';

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
            Restart = "always";
            RestartSec = "10s";
            NoNewPrivileges = true;
          };
        };

      };
  };
}
