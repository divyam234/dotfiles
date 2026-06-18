{
  laptop = {
    system = "x86_64-linux";
    hostName = "laptop";
    user = "bhunter";
    role = "workstation";

    features = [
      "btrfs"
      "containers"
      "gaming"
      "tailscale"
    ];

    services = [ ];

    secretsFile = ../hosts/laptop/secrets.yaml;
    primaryDisplay = {
      name = null;
      width = null;
      height = null;
      refreshRate = null;
      scale = null;
    };
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
