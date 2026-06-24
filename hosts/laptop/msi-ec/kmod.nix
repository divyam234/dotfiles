{ config, lib, pkgs, ... }:

let
  kernelPackages = config.boot.kernelPackages;
  kernel = kernelPackages.kernel;
in {
  services.dbus.packages = [ pkgs.mcontrolcenter ];

  boot.extraModulePackages = [
    (kernelPackages.stdenv.mkDerivation {
      pname = "msi-ec-kmods";
      version = "0-unstable-2025-06-23";

      src = pkgs.fetchFromGitHub {
        owner = "BeardOverflow";
        repo = "msi-ec";
        rev = "6b5c015adf9dbf7e0bd4acf02c3b4f3cce9b50a3";
        hash = "sha256-/TfUxabvhpvbZTlEISLcmJyRVtTqrU5UA2dtCKr9EFU=";
      };

      patches = [ ./firmware-support.patch ];

      hardeningDisable = [ "pic" ];

      makeFlags = kernelPackages.kernelModuleMakeFlags ++ [
        "KERNELDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
        "INSTALL_MOD_PATH=$(out)"
      ];

      nativeBuildInputs = kernel.moduleBuildDependencies;

      installTargets = [ "modules_install" ];

      enableParallelBuilding = true;
    })
  ];
  boot.kernelModules = [ "msi-ec" "ec_sys" ];
  boot.extraModprobeConfig = "options ec_sys write_support=1";
}
