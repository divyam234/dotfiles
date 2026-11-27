{ den, ... }:
{
  den.aspects.camofox = {
    nixosSecrets = [ "camofox/api_key" ];

    nixos =
      { containers, secrets, ... }:
      {
        virtualisation.quadlet.containers.camofox-browser = {
          secretEnvironment.MCP_CAMOUFOX_API_KEY = secrets.camofox.api_key;
          containerConfig = {
            image = "ghcr.io/tgdrive/camofox-browser:latest";
            healthCmd = "none";
            networkAliases = [ "camofox-browser" ];
            environments = {
              MCP_CAMOUFOX_HOST = "0.0.0.0";
              MCP_CAMOUFOX_PORT = "9377";
            };
            publishPorts = [ "9377:9377" ];
            podmanArgs = [ "--shm-size=1g" ];
          };
          serviceConfig = {
            MemoryMax = "4G";
            CPUQuota = "200%";
          };
        };

        networking.firewall.interfaces."br-${containers.networkName}".allowedTCPPorts = [ 9377 ];
        networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 9377 ];
      };
  };
}
