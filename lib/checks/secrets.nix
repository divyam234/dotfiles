{
  home,
  homelab,
  laptop,
  netcup,
}:
let
  expectedCommon = [
    "cloudflare/api_token"
    "codeforge/token"
    "github/token"
    "nordvpn/private_key"
    "nordvpn/token"
    "ssh/private_key"
    "tailscale/oauth_client_secret"
    "users/bhunter/password"
  ];
  expectedNetcup = expectedCommon ++ [
    "gproxy/admin_password"
    "gproxy/master_key"
    "postgres/password"
    "postgres/user"
    "redis/password"
    "restic/password"
    "restic/rclone_conf"
    "restic/repository"
    "vaultwarden/admin_token"
  ];
  expectedHomelab = expectedCommon ++ [ "rclone/postgres_url" ];
  netcupHome = netcup.home-manager.users.bhunter;
  expectedTemplates = [
    "caddy.env"
    "forgejo.env"
    "gluetun.env"
    "gproxy.env"
    "postgres.env"
    "redis.env"
    "vaultwarden.env"
  ];
in
assert builtins.attrNames laptop.sops.secrets == builtins.sort builtins.lessThan expectedCommon;
assert builtins.attrNames homelab.sops.secrets == builtins.sort builtins.lessThan expectedHomelab;
assert builtins.attrNames netcup.sops.secrets == builtins.sort builtins.lessThan expectedNetcup;
assert
  builtins.attrNames netcup.sops.templates == builtins.sort builtins.lessThan expectedTemplates;
assert netcupHome.sops.age.keyFile == "/home/bhunter/.config/sops/age/keys.txt";
assert builtins.hasAttr "sops-nix" netcupHome.systemd.user.services;
assert home.sops.age.keyFile == "/home/bhunter/.config/sops/age/keys.txt";
assert builtins.hasAttr "sops-nix" home.systemd.user.services;
true
