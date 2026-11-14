{ den, ... }:
{
  # First-boot native NixOS for Motorola Capri: essentials only.
  # Keep hardware modules in hosts/capri; do not inherit the desktop,
  # development, container, or general server package collections.
  den.aspects.capri-minimal = {
    includes = [
      den.aspects.facter
      den.aspects.tailscale
    ];

    nixos = { lib, pkgs, ... }: {
      # Test-image recovery: enter the local VT as bhunter without PAM
      # password authentication. Keep remote SSH strictly key-only.
      services.getty.autologinUser = "bhunter";
      # Password-login remains disabled even if the SOPS password secret exists.
      users.mutableUsers = false;
      users.users.bhunter = {
        hashedPasswordFile = lib.mkForce null;
        hashedPassword = lib.mkForce "!";
      };
      security.sudo.wheelNeedsPassword = false;
      # Retain the existing SSH port and public-key-only access over USB/Wi-Fi.
      services.openssh = {
        enable = true;
        ports = [ 2222 ];
        openFirewall = true;
        settings = {
          PermitRootLogin = "no";
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          StreamLocalBindUnlink = "yes";
        };
      };
      # Native nftables avoids unsupported xtables/pkttype compatibility matches.
      networking.nftables.enable = true;
      networking.firewall.enable = true;
      services.fail2ban.enable = true;

      # Keep on-device Nix ready for later flake-based deployments without
      # installing a compiler, a development environment or a desktop.
      nix.channel.enable = false;
      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
      ];

      # First-boot recovery is through SSH and this flake, not an on-device
      # NixOS installer or local documentation. Keep rsync and strace useful
      # for remote deployment and driver debugging.
      system.disableInstallerTools = true;
      documentation.enable = false;
      environment.defaultPackages = with pkgs; [
        git
        rsync
        strace
        jq
        htop
        ethtool
        tcpdump
        lsof
      ];
      boot.loader.timeout = 3;
      time.timeZone = "Asia/Kolkata";
    };
  };
}
