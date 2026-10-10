_: {
  den.hosts.aarch64-linux.netcup = {
    secretsFile = ../../../hosts/netcup/secrets.yaml;
    dns.publicTarget.ipv4.source = "local";
    users.bhunter = { };
  };
}
