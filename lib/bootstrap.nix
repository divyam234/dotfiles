{ inputs, lib }:
let
  dotfilesLib = import ./default.nix { inherit inputs lib; };

  overlays = [
    inputs.rust-overlay.overlays.default
    inputs.nix-pkgs.overlays.default
    inputs.cachyos-kernel.overlays.pinned
    (final: _prev: {
      local =
        let
          rustToolchain = final.rust-bin.stable.latest.default;
          rustPlatform = final.makeRustPlatform {
            cargo = rustToolchain;
            rustc = rustToolchain;
          };
        in
        dotfilesLib.importPackages final ../packages
        // {
          svc = final.callPackage ../packages/svc { inherit rustPlatform; };
        };
    })
  ];
in
{
  inherit dotfilesLib overlays;
}
