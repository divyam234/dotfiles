{ dotUsers, ... }:
{
  den.hosts.x86_64-linux.homepc = {
    users.bhunter = dotUsers.bhunter;
    role = "workstation";
    features = [
      "btrfs"
      "containers"
      "gaming"
      "tailscale"
    ];
  };

  den.hosts.aarch64-linux.netcup = {
    users.bhunter = dotUsers.bhunter;
    role = "server";
    features = [
      "containers"
      "tailscale"
    ];
    services = [
      "caddy"
      "postgres"
      "redis"
      "pgdog"
      "databasus"
      "forgejo"
      "vaultwarden"
      "gluetun"
      "adguard"
      "camofox"
      "hermes"
      "siyuan"
      "restic"
    ];
    domain = "example.com";
    caddyEmail = dotUsers.bhunter.email;
  };
}
