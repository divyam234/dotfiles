_: {
  den.hosts.x86_64-linux.laptop = {
    outputs = [
      {
        name = "eDP-1";
        off = true;
      }
      {
        name = "HDMI-A-2";
        mode = "1920x1080@74.973";
        scale = 1.25;
      }
      {
        name = "HDMI-A-1";
        mode = "1920x1080@74.973";
        scale = 1.25;
      }
    ];

    users.bhunter.classes = [ "user" ];
  };
}
