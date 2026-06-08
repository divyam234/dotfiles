let
  bhunter = {
    userName = "bhunter";
    fullName = "Bhunter";
    email = "47589864+divyam234@users.noreply.github.com";
    signingKey = "~/.ssh/id_ed25519.pub";
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICWt7MJWVbCBzlYidynsuu9kP5kB5/gcUBFO+K6ciyCC"
    ];
  };
in
{
  den.hosts.x86_64-linux.homepc = {
    users.bhunter = bhunter;
    isServer = false;
    autologin = false;
  };

  den.hosts.aarch64-linux.netcup = {
    users.bhunter = bhunter;
    isServer = true;
    autologin = false;
    domain = "example.com";
    caddyEmail = bhunter.email;
  };

  den.homes.x86_64-linux."bhunter@homepc" = { };
}
