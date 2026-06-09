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

  # User marker aspect. Host-selected NixOS/Home Manager aspects are forwarded
  # by modules/policies/host-dispatch.nix via provides.to-users. Keep this empty
  # to avoid double-projecting host aspects into Home Manager.
  den.aspects.bhunter = { };
}
