{ den, ... }:
let
  bhunterPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICWt7MJWVbCBzlYidynsuu9kP5kB5/gcUBFO+K6ciyCC";
in
{
  den.aspects.ssh = {
    homeManager =
      { config, ... }:
      {
        # Home Manager's programs.ssh module writes ~/.ssh/config, but these
        # companion files are deliberately managed here so git SSH signing and
        # tools that expect the public key are deterministic too.
        home.file.".ssh/id_ed25519.pub".text = bhunterPublicKey + "\n";
        home.file.".ssh/allowed_signers".text = "* ${bhunterPublicKey}\n";

        programs.ssh = {
          enable = true;
          enableDefaultConfig = false;
          settings = {
            "*" = {
              AddKeysToAgent = "yes";
              Compression = true;
              ControlMaster = "auto";
              ControlPersist = "10m";
              ServerAliveInterval = 60;
              ServerAliveCountMax = 3;
              HashKnownHosts = false;
              UserKnownHostsFile = "~/.ssh/known_hosts";
              ControlPath = "~/.ssh/master-%r@%n:%p";
            };
            "github.com" = {
              HostName = "github.com";
              User = "git";
              IdentitiesOnly = true;
              IdentityFile = "~/.ssh/id_ed25519";
            };
          };
        };

        sops.secrets."ssh/id_ed25519" = {
          sopsFile = ../../secrets/files/id_ed25519;
          format = "binary";
          path = "${config.home.homeDirectory}/.ssh/id_ed25519";
          mode = "0600";
        };
      };
  };
}
