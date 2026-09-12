{ den, lib, ... }:
let
  signingPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICWt7MJWVbCBzlYidynsuu9kP5kB5/gcUBFO+K6ciyCC";
in
{
  den.schema.user.config = {
    uid = lib.mkDefault 1000;
    fullName = lib.mkDefault "Bhunter";
    gitName = lib.mkDefault "Divyam";
    githubUser = lib.mkDefault "divyam234";
    email = lib.mkDefault "47589864+divyam234@users.noreply.github.com";
    signingKey = lib.mkDefault ".ssh/id_ed25519.pub";
    signingPublicKey = lib.mkDefault signingPublicKey;
    authorizedKeys = lib.mkDefault [ signingPublicKey ];
  };

  den.aspects.bhunter = {
    includes = [
      den.batteries.host-aspects
      den.aspects.user-signing
    ];
  };
}
