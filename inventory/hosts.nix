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
    outputs = [
      {
        name = "eDP-1";
        off = true;
      }
      {
        name = "HDMI-A-1";
        mode = "1920x1080@74.973";
        scale = 1.25;
      }
      {
        name = "HDMI-A-2";
        mode = "1920x1080@74.973";
        scale = 1.25;
      }
    ];
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
      "codeforge-mcp"
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
