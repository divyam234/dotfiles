{ inputs, den, ... }:
{
  flake-file.inputs.nordvpn-nix = {
    url = "github:Triforcey/nordvpn-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.desktop = {
    includes = [
      den.aspects.development
      den.aspects.fonts
      den.aspects.portals
      den.aspects.desktop-apps
      den.aspects.gnome-apps
      den.aspects.kde-packages
      den.aspects.brave
      den.aspects.niri
      den.aspects.noctalia
      den.aspects.ghostty
      den.aspects.zed
      den.aspects.sublime
    ];

    nixos =
      { pkgs, user, ... }:
      {
        imports = [ inputs.nordvpn-nix.nixosModules.nordvpn ];

        networking.networkmanager.enable = true;
        hardware.bluetooth.enable = true;
        hardware.logitech.wireless = {
          enable = true;
          enableGraphical = true;
        };
        security.polkit.enable = true;
        programs.dconf.enable = true;

        services = {
          dbus.enable = true;
          gvfs.enable = true;
          udisks2.enable = true;
          upower.enable = true;
          power-profiles-daemon.enable = true;
          gnome.gnome-keyring.enable = true;
          blueman.enable = true;
          pipewire = {
            enable = true;
            pulse.enable = true;
            alsa.enable = true;
            alsa.support32Bit = true;
            jack.enable = true;
          };

          nordvpn = {
            enable = true;
            openFirewall = false;
            users = [ user.userName ];
            gui.enable = false;
          };
        };

        users.users.${user.userName}.extraGroups = [
          "networkmanager"
          "audio"
          "video"
          "input"
          "render"
          "storage"
        ];

        environment = {
          sessionVariables = {
            GDK_BACKEND = "wayland,x11";
            NIXOS_OZONE_WL = "1";
            SDL_VIDEODRIVER = "wayland";
          };
        };
      };

    homeManager = {
      gtk.enable = true;

      xdg = {
        enable = true;
        userDirs = {
          enable = true;
          createDirectories = true;
        };
      };
    };
  };
}
