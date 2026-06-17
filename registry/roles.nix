{
  workstation = {
    description = "Interactive graphical workstation";
    features = [
      "desktop"
      "development"
      "security-workstation"
    ];
    supportedSystems = [ "x86_64-linux" ];
  };

  server = {
    description = "Headless production server";
    features = [
      "development"
      "firewall"
      "fail2ban"
      "security-server"
    ];
    supportedSystems = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
