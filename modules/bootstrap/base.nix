{ den, ... }:
{
  den.default = {
    includes = [
      den._.define-user
      den._.hostname
    ];

    homeManager.home.stateVersion = "25.11";
  };
}
