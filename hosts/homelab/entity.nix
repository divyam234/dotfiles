_: {
  den.hosts.x86_64-linux.homelab = {
    secretsFile = ./secrets.yaml;
    dns = {
      refreshInterval = "15m";
      publicTarget = {
        ipv4.enable = false;
        ipv6 = {
          enable = true;
          source = "external";
        };
      };
    };
    users.bhunter = { };
  };
}
