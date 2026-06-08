{ den, ... }:
{
  den.aspects.ssh = {
    homeManager =
      { config, ... }:
      {
        home.file.".ssh/id_ed25519.pub".text = ''
          ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICWt7MJWVbCBzlYidynsuu9kP5kB5/gcUBFO+K6ciyCC
        '';

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
