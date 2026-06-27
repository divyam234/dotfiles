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
      burpsuitepro =
        inputs.burpsuite-pro.packages.${final.stdenv.hostPlatform.system}.burpsuitepro.override
          {
            jdk = final.jetbrains.jdk-21;
          };
    })
    (final: _prev: {
      local = extendedLib.denful.importPackages final ../packages;
    })
  ];
in
{
  inherit extendedLib overlays;
}
