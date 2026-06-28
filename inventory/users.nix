{
  bhunter = rec {
    userName = "bhunter";
    fullName = "Bhunter";
    email = "bhunter@localhost";
    signingKey = "~/.ssh/id_ed25519.pub";
    signingPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICWt7MJWVbCBzlYidynsuu9kP5kB5/gcUBFO+K6ciyCC";

    authorizedKeys = [
      signingPublicKey
    ];
  };
}
