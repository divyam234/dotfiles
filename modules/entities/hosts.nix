{ dotUsers, ... }:
{
  den.hosts.x86_64-linux.laptop = {
    users.bhunter = dotUsers.bhunter;
    role = "workstation";
    features = [
      "btrfs"
      "containers"
      "gaming"
      "tailscale"
    ];
    secretsFile = ../../hosts/laptop/secrets.yaml;
  };

  den.hosts.aarch64-linux.netcup = {
    users.bhunter = dotUsers.bhunter;
    role = "minimal";
    features = [
      "containers"
      "tailscale"
    ];
    services = {
      adguard.enable = true;
      caddy.enable = true;
      camofox.enable = true;
      databasus.enable = true;
      forgejo.enable = true;
      gluetun.enable = true;
      hermes.enable = true;
      pgdog.enable = true;
      postgres.enable = true;
      redis.enable = true;
      restic.enable = true;
      siyuan.enable = true;
      vaultwarden.enable = true;
    };
    domain = "example.com";
    caddyEmail = dotUsers.bhunter.email;
    secretsFile = ../../hosts/netcup/secrets.yaml;
  };
}
