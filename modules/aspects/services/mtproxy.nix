{ den, ... }:
{
  den.aspects.mtproxy = _: {
    nixosSecrets = [ "mtproxy/secret" ];

    nixos =
      {
        secrets,
        ...
      }:
      {
        virtualisation.quadlet.containers.mtproxy = {
          secretEnvironment.SECRET = secrets.mtproxy.secret;
          containerConfig = {
            image = "ghcr.io/teleproxy/teleproxy:latest";
            networkAliases = [ "mtproxy" ];
            publishPorts = [ "8670:443" ];
            environments = {
              DIRECT_MODE = "true";
              WORKERS = "2";
            };
          };
          serviceConfig = {
            MemoryMax = "512M";
            CPUQuota = "100%";
          };
        };
      };
  };
}
