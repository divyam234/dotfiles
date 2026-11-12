{ config, pkgs }:
let
  # Verified GPT entry 77: 98007007 sectors, each 512 bytes. The image must
  # fit the existing partition; it contains no GPT or bootloader sectors.
  userdataBytes = 98007007 * 512;
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
  name = "capri-userdata.ext4";
  buildCommand = old.buildCommand + ''
    bytes=$(stat -c %s "$out")
    if (( bytes > ${toString userdataBytes} )); then
      echo "Capri rootfs image exceeds the verified userdata partition size" >&2
      exit 1
    fi
  '';
})
