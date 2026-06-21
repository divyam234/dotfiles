{ inputs, lib }:
let
  extendedLib = lib.extend (
    self: _super: {
      denful = import ./default.nix {
        inherit inputs;
        lib = self;
      };
    }
  );

  overlays = [
    inputs.nur.overlays.default
    inputs.rust-overlay.overlays.default
    inputs.nix-pkgs.overlays.default
    (final: prev: {
      local = extendedLib.denful.importPackages final ../packages;
    })
  ];
in
{
  inherit extendedLib overlays;
}
