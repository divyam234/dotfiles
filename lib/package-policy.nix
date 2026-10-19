{ inputs, lib }:
let
  dotBootstrap = import ./bootstrap.nix { inherit inputs lib; };
in
{
  config.allowUnfree = true;
  config.permittedInsecurePackages = [
    "pnpm-10.29.2"
  ];
  inherit (dotBootstrap) overlays;
}
