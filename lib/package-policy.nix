{ inputs, lib }:
let
  dotBootstrap = import ./bootstrap.nix { inherit inputs lib; };
in
{
  config.allowUnfree = true;
  inherit (dotBootstrap) overlays;
}
