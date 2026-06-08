{ den, ... }:
{
  den.aspects.ssh = {
    homeManager = { ... }: {
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
    };
  };
}
