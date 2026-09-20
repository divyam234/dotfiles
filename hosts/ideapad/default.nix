{ den, ... }:
{
  den.aspects.ideapad = {
    includes = [
      den.aspects.base
      den.aspects.workstation
      den.aspects.cachyos-kernel
      den.aspects.home-manager-policy
      den.aspects.oci-base
      den.aspects.container-network
    ];

    nixos =
      { lib, pkgs, ... }:
      {
        imports = [ ./disko.nix ];

        boot = {
          initrd.kernelModules = [
            "amdgpu"
            "i915"
          ];
        };

        environment = {
          sessionVariables.LIBVA_DRIVER_NAME = "iHD";
          systemPackages = with pkgs; [
            ffmpeg-full
            intel-gpu-tools
            libva-utils
            mesa-demos
            nvtopPackages.full
            vulkan-tools
          ];
        };

        facter.reportPath = ./facter.json;

        fileSystems."/mnt/drive" = {
          device = "/dev/disk/by-id/ata-ST1000LM035-1RK172_WDE7K055-part1";
          fsType = "ext4";
          options = [
            "nofail"
            "x-systemd.automount"
            "x-gvfs-show"
            "noatime"
          ];
        };

        hardware.graphics = {
          enable = true;
          enable32Bit = true;
          extraPackages = [ pkgs.intel-media-driver ];
        };

        networking.useDHCP = lib.mkDefault true;
        system.stateVersion = "26.05";
      };
  };
}
