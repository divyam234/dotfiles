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
        extendedLib.denful.importPackages final ../packages
        // {
          svc = final.callPackage ../packages/svc { inherit rustPlatform; };
        };
    })
  ];
in
{
  inherit extendedLib overlays;
}
