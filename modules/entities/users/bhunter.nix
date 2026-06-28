{ den, ... }:
let
  bhunter = rec {
    userName = "bhunter";
    uid = 1000;
    fullName = "Bhunter";
    email = "bhunter@localhost";
    signingKey = "~/.ssh/id_ed25519.pub";
    signingPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICWt7MJWVbCBzlYidynsuu9kP5kB5/gcUBFO+K6ciyCC";
    authorizedKeys = [ signingPublicKey ];
  };
in
{
  _module.args.bhunterUser = bhunter;

  den.aspects.bhunter = {
    includes = [
      den.batteries.host-aspects
      den.aspects.user-signing
    ];

    provides.laptop.includes = [ den.aspects.laptop ];
  };
}
