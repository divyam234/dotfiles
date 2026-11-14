{ config, pkgs }:
let
  # ADB verified removable /dev/block/mmcblk1p1: 124702720 sectors of 512 bytes.
  # This is only a filesystem image: never overwrite the entire microSD device.
  microsdPartitionBytes = 124702720 * 512;
  image = pkgs.callPackage (pkgs.path + "/nixos/lib/make-ext4-fs.nix") {
    storePaths = [ config.system.build.toplevel ];
    volumeLabel = "NIXOS_CAPRI";
    populateImageCommands = ''
      mkdir -p ./files/boot
      ${config.boot.loader.generic-extlinux-compatible.populateCmd} \
        -g 0 -c ${config.system.build.toplevel} -d ./files/boot
    '';
  };
in
image.overrideAttrs (old: {
  name = "capri-microsd.ext4";
  buildCommand = old.buildCommand + ''
    bytes=$(stat -c %s "$out")
    if (( bytes > ${toString microsdPartitionBytes} )); then
      echo "Capri rootfs image exceeds the verified microSD partition size" >&2
      exit 1
    fi
  '';
})
