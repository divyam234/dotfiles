{ den, ... }:
{
  den.aspects.ssh = {
    homeManager =
      { config, ... }:
      {
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
        sops.secrets."ssh/private_key" = {
          path = "${config.home.homeDirectory}/.ssh/id_ed25519";
          mode = "0600";
        };
      };
  };
}
