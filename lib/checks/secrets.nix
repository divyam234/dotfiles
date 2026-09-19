{
  home,
  homelab,
  laptop,
  netcup,
}:
let
  expectedLaptop = [
    "tailscale/oauth_client_secret"
    "users/bhunter/password"
  ];
  expectedHomelab = [
    "cloudflare/api_token"
    "github/token"
    "tailscale/oauth_client_secret"
    "users/bhunter/password"
  ];
  expectedNetcup = [
    "camofox/access_key"
    "camofox/admin_key"
    "camofox/api_key"
    "cloudflare/api_token"
    "gateauth/admin_email"
    "gateauth/admin_password"
    "gateauth/better_auth_secret"
    "gemini-fastapi/api_key"
    "gemini-fastapi/secure_1psid"
    "gemini-fastapi/secure_1psidts"
    "github/token"
    "gproxy/admin_password"
    "gproxy/master_key"
    "mtproxy/secret"
    "nordvpn/private_key"
    "postgres/password"
    "postgres/user"
    "redis/password"
    "restic/password"
    "restic/rclone_conf"
    "restic/repository"
    "stash/secret_key"
    "tailscale/oauth_client_secret"
    "teldrive/api_key"
    "teldrive/data_key"
    "teldrive/encryption_key"
    "teldrive/signing_key"
    "users/bhunter/password"
    "vaultwarden/admin_token"
  ];
  expectedLaptopHome = [
    "github/token"
    "nordvpn/token"
    "openai/api_key"
    "ssh/private_key"
  ];
  expectedHomelabHome = [
    "github/token"
    "openai/api_key"
    "ssh/private_key"
  ];
  expectedNetcupHome = [
    "camofox/access_key"
    "camofox/admin_key"
    "camofox/api_key"
    "codeforge/token"
    "github/token"
    "openai/api_key"
    "ssh/private_key"
  ];
  homelabHome = homelab.home-manager.users.bhunter;
  netcupHome = netcup.home-manager.users.bhunter;
  expectedTemplates = [
    "caddy.env"
    "camofox.env"
    "cloudflare-dns.env"
    "forgejo.env"
    "gateauth.env"
    "gemini-fastapi.env"
    "gluetun.env"
    "gproxy.env"
    "mtproxy.env"
    "postgres.env"
    "redis.env"
    "stash-worker.env"
    "stash.env"
    "teldrive.env"
    "vaultwarden.env"
  ];
in
assert builtins.attrNames laptop.sops.secrets == expectedLaptop;
assert builtins.attrNames homelab.sops.secrets == builtins.sort builtins.lessThan expectedHomelab;
assert builtins.attrNames netcup.sops.secrets == expectedNetcup;
assert builtins.attrNames home.sops.secrets == expectedLaptopHome;
assert builtins.attrNames homelabHome.sops.secrets == expectedHomelabHome;
assert builtins.attrNames netcupHome.sops.secrets == expectedNetcupHome;
assert
  builtins.attrNames netcup.sops.templates == builtins.sort builtins.lessThan expectedTemplates;
assert netcupHome.sops.age.keyFile == "/var/lib/sops-nix/key.txt";
assert builtins.hasAttr "sops-nix" netcupHome.systemd.user.services;
assert home.sops.age.keyFile == "${home.xdg.configHome}/sops/age/keys.txt";
assert builtins.hasAttr "sops-nix" home.systemd.user.services;
true
