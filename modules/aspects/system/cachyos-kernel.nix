{ den, inputs, ... }:
{
  flake-file.inputs.cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";

  den.aspects.cachyos-kernel.nixos =
    { pkgs, ... }:
    {
      nixpkgs.overlays = [ inputs.cachyos-kernel.overlays.pinned ];
      boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest-x86_64-v3;
    };
}
