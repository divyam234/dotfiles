{
  laptop = {
    system = "x86_64-linux";
    hostName = "laptop";
    user = "bhunter";
    role = "workstation";
    homeManagerMode = "standalone";

    features = [
      "btrfs"
      "containers"
      "tailscale"
    ];

    services = [ ];

    secretsFile = ../hosts/laptop/secrets.yaml;
    tailscale.autoconnect = true;
  };

  netcup = {
    system = "aarch64-linux";
    hostName = "netcup";
    user = "bhunter";
    role = "server";

    features = [
      "tailscale"
    ];

    services = [
      "adguard"
      "camofox"
      "databasus"
      "forgejo"
      "gluetun"
      "hermes"
      "openchamber"
      "redis"
      "restic"
      "siyuan"
      "vaultwarden"
    ];

    domain = "bhunter.tech";
    secretsFile = ../hosts/netcup/secrets.yaml;
    tailscale.autoconnect = true;
  };
}
