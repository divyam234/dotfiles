{ config, pkgs, ... }:
{
  # Grow only the ext4 filesystem inside the existing userdata partition.
  # Never grow/rewrite the handset GPT like a generic whole-disk image.
  fileSystems."/".autoResize = true;
  boot.growPartition = false;

  system.build.rootfsImage = pkgs.callPackage ../../packages/capri/rootfs-image.nix {
    inherit config;
  };

  # Follow NixOS's image initialization convention. Keep the marker until
  # both the store database and the initial system profile are established.
  systemd.services.register-nix-paths = {
    description = "Register initial Nix store paths";
    unitConfig = {
      DefaultDependencies = false;
      ConditionPathExists = "/nix-path-registration";
    };
    wantedBy = [ "sysinit.target" ];
    before = [
      "sysinit.target"
      "shutdown.target"
      "nix-daemon.socket"
      "nix-daemon.service"
    ];
    after = [ "local-fs.target" ];
    conflicts = [ "shutdown.target" ];
    restartIfChanged = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${config.nix.package.out}/bin/nix-store --load-db < /nix-path-registration
      touch /etc/NIXOS
      ${config.nix.package.out}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system
      rm /nix-path-registration
    '';
  };
}
