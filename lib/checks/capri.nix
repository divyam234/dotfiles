{ capri, lib }:
let
  kernel = capri.boot.kernelPackages.kernel;
  service = capri.systemd.services.capri-screen-button;
in
assert kernel.version == "7.4-rc3";
assert kernel.modDirVersion == "7.4.0-rc3-capri";
assert kernel.src.rev == "a8c2f8e868bcf1a3e9ad9d75d0d9aa2f72e9e1ee";
assert capri.hardware.deviceTree.name == "qcom/sm4250-motorola-capri-power.dtb";
assert builtins.elem "novatek/capri-djn-nt36525b.bin" capri.boot.initrd.extraFirmwarePaths;
assert !(builtins.elem "novatek-nt36525b-capri" capri.boot.kernelModules);
assert builtins.elem "multi-user.target" service.wantedBy;
assert builtins.elem "capri-buffyboard.service" service.after;
assert lib.hasSuffix "/bin/capri-screen-button watch" service.serviceConfig.ExecStart;
assert lib.hasSuffix "/bin/capri-screen-button on" service.serviceConfig.ExecStopPost;
assert service.serviceConfig.Restart == "on-failure";
true
