{ den, ... }:
{
  den.aspects.mtproxy = _: {
    nixosSecrets = [ "mtproxy/secret" ];

    nixos =
      {
        containers,
        secrets,
        ...
      }:
      {
        sops.templates."mtproxy.env" = secrets.mkTemplate {
          name = "mtproxy.env";
          content = ''
            SECRET=${secrets.mtproxy.secret}
            DIRECT_MODE=true
            WORKERS=2
          '';
        };

        virtualisation.quadlet.containers.mtproxy = {
          containerConfig = {
            image = "ghcr.io/teleproxy/teleproxy:latest";
            networkAliases = [ "mtproxy" ];
            publishPorts = [ "8670:443" ];
            environmentFiles = [ "${containers.secretDir}/mtproxy.env" ];
          };
          serviceConfig = {
            MemoryMax = "512M";
            CPUQuota = "100%";
          };
        };
      };
  };
}
