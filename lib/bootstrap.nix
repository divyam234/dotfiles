{ inputs, lib }:
let
  dotfilesLib = import ./default.nix { inherit inputs lib; };

  overlays = [
    inputs.nix-pkgs.overlays.default
    inputs.teldrive.overlays.default
    inputs.sonora.overlays.default
    (final: _prev: {
      local = dotfilesLib.importPackages final ../packages;
    })
  ];
in
{
  inherit dotfilesLib overlays;
}
