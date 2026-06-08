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
          addKeysToAgent = "yes";
          compression = true;
          controlMaster = "auto";
          controlPersist = "10m";
          serverAliveInterval = 60;
          serverAliveCountMax = 3;
          matchBlocks = {
            "github.com" = {
              hostname = "github.com";
              user = "git";
              identitiesOnly = true;
              identityFile = "~/.ssh/id_ed25519";
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
