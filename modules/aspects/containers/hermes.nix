{ den, ... }:
{
  den.aspects.hermes = {
    includes = [ den.aspects.oci-service ];
    nixos =
      { lib, host, ... }:
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

        virtualisation.oci-containers.containers.hermes = lib.dot.mkOci "hermes" {
          image = "nousresearch/hermes-agent:latest";
          cmd = [
            "gateway"
            "run"
          ];
          dependsOn = [ "camofox-browser" ];
          environment = {
            HERMES_DASHBOARD = "1";
            HERMES_DASHBOARD_TUI = "1";
            CAMOFOX_URL = "http://camofox-browser:9377";
          };
          extraOptions = [
            "--memory=4g"
            "--cpus=2.0"
          ];
          volumes = [ "${lib.dot.containerDataDir "hermes"}:/opt/data" ];
        };

        dot.caddy.routes.hermes = {
          host = "ai.${host.domain}";
          upstreams = [ "hermes:8642" ];
        };

        systemd.services.podman-hermes = lib.dot.mkContainerDeps "hermes" [ "camofox-browser" ];
      };
  };
}
