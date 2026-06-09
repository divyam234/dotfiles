{ den, ... }:
{
  _module.args.dotUsers.bhunter = {
    userName = "bhunter";
    fullName = "Bhunter";
    signingKey = "~/.ssh/id_ed25519.pub";
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICWt7MJWVbCBzlYidynsuu9kP5kB5/gcUBFO+K6ciyCC"
    ];
  };

  den.aspects.bhunter = {
    includes = [
      # Den's built-in forwarding battery: host-selected homeManager aspects
      # are projected into this user's Home Manager configuration.
      den._.host-aspects
    ];
  };
}
