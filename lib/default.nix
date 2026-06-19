{
  lib,
  inputs ? { },
}:
let
  importPart = path: import path { inherit lib; };
in
importPart ./packages.nix // importPart ./caddy.nix // importPart ./secrets.nix
