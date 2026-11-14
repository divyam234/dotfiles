{ config, pkgs }:
let
  # Verified internal userdata partition /dev/mmcblk0p77: 98007007 sectors
  # of 512 bytes. Only flash that partition from recovery, never the disk.
  emmcPartitionBytes = 98007007 * 512;
  image = pkgs.callPackage (pkgs.path + "/nixos/lib/make-ext4-fs.nix") {
    storePaths = [ config.system.build.toplevel ];
    volumeLabel = "NIXOS_EMMC";
    populateImageCommands = ''
      mkdir -p ./files/boot
      ${config.boot.loader.generic-extlinux-compatible.populateCmd} \
        -g 0 -c ${config.system.build.toplevel} -d ./files/boot
    '';
  };
in
image.overrideAttrs (old: {
  name = "capri-emmc.ext4";
  buildCommand = old.buildCommand + ''
    bytes=$(stat -c %s "$out")
    if (( bytes > ${toString emmcPartitionBytes} )); then
      echo "Capri rootfs image exceeds the verified eMMC userdata partition size" >&2
      exit 1
    fi
  '';
})
