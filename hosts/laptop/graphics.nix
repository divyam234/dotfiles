{ config, pkgs, ... }:
{
  boot.initrd.kernelModules = [ "i915" ];
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver
      nvidia-vaapi-driver
    ];
  };

  services.xserver.videoDrivers = [
    "modesetting"
    "nvidia"
  ];

  hardware.nvidia = {
    # GTX 1050 Mobile is Pascal: use the proprietary module and the final
    # supported long-lived driver branch rather than the open kernel module.
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
    modesetting.enable = true;
    nvidiaSettings = true;

    prime = {
      intelBusId = "PCI:0@0:2:0";
      nvidiaBusId = "PCI:1@0:0:0";
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
    };
  };

  # Keep Niri and browsers on the efficient UHD 630/iHD path. Use
  # nvidia-offload explicitly for games, CUDA, NVDEC/NVENC and heavy graphics.
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

  environment.systemPackages = with pkgs; [
    libva-utils
    vulkan-tools
    mesa-demos
    intel-gpu-tools
    nvtopPackages.full
    ffmpeg-full
  ];
}
