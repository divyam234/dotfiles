{ den, ... }:
{
  den.aspects.btrfs = {
    nixos = _: {
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
