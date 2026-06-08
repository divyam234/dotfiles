{ inputs, lib, ... }:
{
  _module.args.dotBootstrap = import ../../lib/bootstrap.nix { inherit inputs lib; };
}
