{
  ai = {
    description = "AI coding and agent tooling";
  };

  btrfs = {
    description = "Btrfs filesystem support and maintenance";
    supportedSystems = [ "x86_64-linux" ];
  };

  containers = {
    description = "Rootful Podman and Quadlet service containers";
    aspect = "oci-base";
  };

  desktop = {
    description = "Niri desktop, Noctalia shell, KDE applications, portals and theming";
    supportedSystems = [ "x86_64-linux" ];
  };

  development = {
    description = "Development shells, editor, CLI tools and terminal workflow";
  };

  fail2ban = {
    description = "Brute-force protection for public server services";
    requires = [ "firewall" ];
  };

  firewall = {
    description = "Host firewall baseline";
  };

  gaming = {
    description = "Gaming packages and system configuration";
    requires = [ "desktop" ];
    supportedSystems = [ "x86_64-linux" ];
  };

  security-server = {
    description = "Strict server security policy";
  };

  security-workstation = {
    description = "Workstation security policy with local conveniences";
    supportedSystems = [ "x86_64-linux" ];
  };

  tailscale = {
    description = "Tailscale mesh networking";
  };
}
