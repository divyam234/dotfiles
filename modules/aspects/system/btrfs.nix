{ den, ... }:
{
  den.aspects.btrfs = {
    nixos =
      { ... }:
      {
        services.btrfs.autoScrub = {
          enable = true;
          interval = "monthly";
          fileSystems = [ "/" ];
        };
        zramSwap = {
          enable = true;
          algorithm = "zstd";
          memoryPercent = 25;
        };
      };
  };
}
