{ capri, lib }:
assert capri.nixpkgs.hostPlatform.system == "aarch64-linux";
assert capri.boot.kernelPackages.kernel.version == "7.2.9";
assert capri.boot.kernelPackages.kernel.modDirVersion == "7.2.9-capri";
assert
  lib.length (
    builtins.filter (
      patch: patch.name or "" == "capri-power-charging"
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
assert capri.fileSystems."/".device == "/dev/disk/by-partuuid/f6eb68be-3488-aaba-703b-eb107625d212";
assert !(builtins.hasAttr "/boot" capri.fileSystems);
assert !capri.boot.loader.efi.canTouchEfiVariables;
assert capri.boot.kernelPackages.kernel.features.efiBootStub;
assert lib.versions.major capri.systemd.package.version == "262";
assert capri.boot.loader.timeout == 3;
assert capri ? facter;
assert capri.services.fail2ban.enable;
assert capri.services.tailscale.enable;
assert capri.services.openssh.ports == [ 2222 ];
assert !capri.services.openssh.settings.PasswordAuthentication;
assert lib.elem 2222 capri.networking.firewall.allowedTCPPorts;
assert capri.sops.age.keyFile == "/var/lib/sops-nix/key.txt";
assert capri.sops.secrets."users/bhunter/password".neededForUsers;
assert capri.home-manager.users.bhunter.home.username == "bhunter";
assert capri.networking.networkmanager.enable;
assert lib.elem "interface-name:usb*" capri.networking.networkmanager.unmanaged;
assert lib.elem "multi-user.target" capri.systemd.services.capri-usb-ecm.wantedBy;
assert capri.systemd.services.capri-usb-ecm.serviceConfig.Type == "oneshot";
assert capri.systemd.services.capri-usb-ecm.serviceConfig.Restart == "on-failure";
assert capri.users.users.capriusb.password == "";
assert !(lib.elem "wheel" capri.users.users.capriusb.extraGroups);
assert capri.security.sudo.enable;
assert lib.any (
  rule:
  rule.users == [ "capriusb" ]
  && lib.any (command: command.command == "ALL" && lib.elem "NOPASSWD" command.options) rule.commands
) capri.security.sudo.extraRules;
assert !(lib.elem 2223 capri.networking.firewall.allowedTCPPorts);
assert capri.networking.firewall.interfaces.usb0.allowedTCPPorts == [ 2223 ];
assert lib.elem "multi-user.target" capri.systemd.services.capri-usb-sshd.wantedBy;
assert lib.elem "capri-usb-ecm.service" capri.systemd.services.capri-usb-sshd.requires;
assert lib.hasInfix "sshd -D -e -f" capri.systemd.services.capri-usb-sshd.serviceConfig.ExecStart;
assert !capri.networking.modemmanager.enable;
assert capri.hardware.firmwareCompression == "none";
assert capri.systemd.services.capri-rmtfs.serviceConfig.ExecStart != "";
assert capri.systemd.services.capri-wifi-driver.serviceConfig.ExecStart != "";
assert lib.elem "novatek-nt36525b-capri" capri.boot.kernelModules;
assert lib.elem "multi-user.target" capri.systemd.services.capri-buffyboard.wantedBy;
assert capri.systemd.services.capri-buffyboard.serviceConfig.Restart == "always";
assert capri.console.font == "ter-128n";
assert capri.services.getty.autologinUser == null;
assert !capri.virtualisation.podman.enable;
assert !capri.virtualisation.containers.enable;
assert !capri.services.caddy.enable;
assert builtins.attrNames capri.virtualisation.quadlet.containers == [ ];
true
