{
  bhunterUser,
  entityLib,
  ...
}:
{
  den.hosts.x86_64-linux.laptop = {
    hostName = "laptop";
    user = "bhunter";
    secretsFile = ../../../hosts/laptop/secrets.yaml;
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

    instantiate = entityLib.mkNixos "x86_64-linux";

    users.bhunter = bhunterUser // {
      classes = [ ];
    };
  };
}
