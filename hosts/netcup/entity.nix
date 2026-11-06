_: {
  den.hosts.aarch64-linux.netcup = {
    secretsFile = ./secrets.yaml;
    dns.publicTarget.ipv4.source = "local";
    tailscale.exitNode = true;
    users.bhunter = { };
  };
}
