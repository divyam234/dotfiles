{ den, ... }:
{
  den.aspects.hermes = {
    includes = [ den.aspects.oci-service ];
    nixos =
      {
        config,
        lib,
        host,
        ...
      }:
      let
        quadlet = config.virtualisation.quadlet;
      in
      {
        systemd.tmpfiles.rules = lib.dot.mkServiceDirRules [ "hermes" ];

        # Seed hermes config on first boot
        system.activationScripts.seedHermesConfig = ''
          if [ ! -f ${lib.dot.containerDataDir "hermes"}/config.yaml ]; then
            mkdir -p ${lib.dot.containerDataDir "hermes"}
            cat > ${lib.dot.containerDataDir "hermes"}/config.yaml << 'EOF'
          browser:
            camofox:
              managed_persistence: true
          EOF
            chmod 666 ${lib.dot.containerDataDir "hermes"}/config.yaml
          fi
        '';

        virtualisation.quadlet.containers.hermes = {
          autoStart = false;
          containerConfig = {
            image = "docker.io/nousresearch/hermes-agent:latest";
            networks = [ quadlet.networks.${lib.dot.containerNetwork}.ref ];
            exec = [
              "gateway"
              "run"
            ];
            environments = {
              HERMES_DASHBOARD = "1";
              HERMES_DASHBOARD_TUI = "1";
              CAMOFOX_URL = "http://camofox-browser:9377";
            };
            memory = "4g";
            podmanArgs = [ "--cpus=2.0" ];
            volumes = [ "${lib.dot.containerDataDir "hermes"}:/opt/data" ];
          };
          unitConfig = {
            After = [ quadlet.containers.camofox-browser.ref ];
            Requires = [ quadlet.containers.camofox-browser.ref ];
          };
          serviceConfig = {
            Restart = "always";
            RestartSec = "10s";
          };
        };

        dot.caddy.routes.hermes = {
          host = "ai.${host.domain}";
          upstreams = [ "hermes:8642" ];
        };
      };
  };
}
