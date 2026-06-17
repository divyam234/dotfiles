{ inputs, lib }:
let
  extendedLib = lib.extend (
    self: _super: {
      dot = import ./default.nix {
        inherit inputs;
        lib = self;
      };
    }
  );

  overlays = [
    inputs.nur.overlays.default
    inputs.rust-overlay.overlays.default
    inputs.nix-pkgs.overlays.default
    (final: _prev: {
      inherit (extendedLib) dot;
      local = extendedLib.dot.importPackages final ../packages;
    })
  ];
in
{
  inherit extendedLib overlays;
}
