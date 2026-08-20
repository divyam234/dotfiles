{ den, ... }:
{
  den.aspects.mtproxy = _: {
    nixos =
      {
        config,
        containers,
        secrets,
        ...
      }:
      let
        quadlet = config.virtualisation.quadlet;
      in
      {
        sops.templates."mtproxy.env" = {
          path = "${containers.secretDir}/mtproxy.env";
          mode = "0440";
          content = ''
            SECRET=${secrets.mtproxy.secret}
            DIRECT_MODE=true
            WORKERS=2
          '';
        };

        virtualisation.quadlet.containers.mtproxy = {
          autoStart = true;
          containerConfig = {
            name = "mtproxy";
            image = "ghcr.io/teleproxy/teleproxy:latest";
            networks = [ quadlet.networks.${containers.networkName}.ref ];
            networkAliases = [ "mtproxy" ];
            environmentFiles = [ "${containers.secretDir}/mtproxy.env" ];
            autoUpdate = "registry";
          };
          serviceConfig = {
            Restart = "always";
            RestartSec = "10s";
            NoNewPrivileges = true;
            MemoryMax = "512M";
            CPUQuota = "100%";
          };
        };
      };
  };
}
