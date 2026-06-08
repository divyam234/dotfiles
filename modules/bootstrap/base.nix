{ den, ... }:
{
  den.default = {
    includes = [
      den._.define-user
      den._.hostname
      den.aspects.boot
    ];

    homeManager.home.stateVersion = "25.11";
  };
}
