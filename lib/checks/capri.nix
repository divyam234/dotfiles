{ capri, lib }:
assert capri.nixpkgs.hostPlatform.system == "aarch64-linux";
assert capri.boot.kernelPackages.kernel.version == "7.2.9";
assert capri.boot.kernelPackages.kernel.modDirVersion == "7.2.9-capri";
assert capri.boot.kernelPackages.kernel.structuredExtraConfig.MSDOS_PARTITION.tristate == "y";
assert
  lib.length (
    builtins.filter (
      patch: patch.name or "" == "capri-native-smb5"
    ) capri.boot.kernelPackages.kernel.kernelPatches
  ) == 1;
assert
  builtins.filter (param: lib.hasPrefix "capri_pmi632_battery." param) capri.boot.kernelParams == [ ];
assert capri.hardware.deviceTree.name == "qcom/sm4250-motorola-capri-power.dtb";
assert !capri.boot.loader.grub.enable;
assert !capri.boot.loader.systemd-boot.enable;
assert capri.boot.loader.generic-extlinux-compatible.enable;
assert capri.boot.loader.generic-extlinux-compatible.useGenerationDeviceTree;
assert capri.fileSystems."/".fsType == "ext4";
assert capri.fileSystems."/".autoResize;
assert !capri.boot.growPartition;
assert capri.fileSystems."/".device == "/dev/disk/by-label/NIXOS_CAPRI";
assert !(builtins.hasAttr "/boot" capri.fileSystems);
assert !capri.boot.loader.efi.canTouchEfiVariables;
assert capri.boot.kernelPackages.kernel.features.efiBootStub;
assert !capri.boot.initrd.allowMissingModules;
assert !(lib.elem "ext2" capri.boot.initrd.availableKernelModules);
assert lib.elem "ext4" capri.boot.initrd.availableKernelModules;
assert lib.versions.major capri.systemd.package.version == "262";
assert capri.boot.loader.timeout == 3;
assert capri ? facter;
assert capri.services.fail2ban.enable;
assert capri.services.tailscale.enable;
assert capri.services.openssh.ports == [ 2222 ];
assert !capri.services.openssh.settings.PasswordAuthentication;
assert lib.elem 2222 capri.networking.firewall.allowedTCPPorts;
assert capri.networking.firewall.allowedTCPPorts == [ 2222 ];
assert capri.networking.firewall.allowedUDPPorts == [ 41641 ];
assert capri.sops.age.keyFile == "/var/lib/sops-nix/key.txt";
assert capri.sops.secrets."users/bhunter/password".neededForUsers;
assert capri.home-manager.users.bhunter.home.username == "bhunter";
assert capri.networking.networkmanager.enable;
assert lib.elem "interface-name:usb*" capri.networking.networkmanager.unmanaged;
assert lib.elem "multi-user.target" capri.systemd.services.capri-usb-ecm.wantedBy;
assert capri.systemd.services.capri-usb-ecm.serviceConfig.Type == "oneshot";
assert capri.systemd.services.capri-usb-ecm.serviceConfig.Restart == "on-failure";
assert !(builtins.hasAttr "capriusb" capri.users.users);
assert !(builtins.hasAttr "capri-usb-sshd" capri.systemd.services);
assert !(lib.elem 2223 capri.networking.firewall.allowedTCPPorts);
assert !capri.networking.modemmanager.enable;
assert capri.hardware.firmwareCompression == "none";
assert capri.systemd.services.capri-rmtfs.serviceConfig.ExecStart != "";
assert capri.systemd.services.capri-wifi-driver.serviceConfig.ExecStart != "";
assert lib.elem "novatek-nt36525b-capri" capri.boot.kernelModules;
assert lib.elem "multi-user.target" capri.systemd.services.capri-buffyboard.wantedBy;
assert capri.systemd.services.capri-buffyboard.serviceConfig.Restart == "always";
assert capri.console.font == "ter-128n";
assert capri.services.getty.autologinUser == "bhunter";
assert !capri.users.mutableUsers;
assert capri.users.users.bhunter.hashedPasswordFile == null;
assert capri.users.users.bhunter.hashedPassword == "!";
assert !capri.security.sudo.wheelNeedsPassword;
assert capri.system.disableInstallerTools;
assert !capri.documentation.enable;
assert !(capri.services ? teldrive);
assert
  !(lib.any (
    p:
    lib.hasPrefix "qemu-" (p.name or "")
    || lib.hasPrefix "rustc-" (p.name or "")
    || lib.hasPrefix "opencode-" (p.name or "")
  ) capri.home-manager.users.bhunter.home.packages);
assert !capri.virtualisation.podman.enable;
assert !capri.virtualisation.containers.enable;
assert !capri.services.caddy.enable;
assert builtins.attrNames capri.virtualisation.quadlet.containers == [ ];
true
