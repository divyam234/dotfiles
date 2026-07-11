{ den, ... }:
{
  den.aspects.sops = {
    nixos = _: {
      sops = {
        defaultSopsFormat = "yaml";
        age.keyFile = "/var/lib/sops-nix/key.txt";
      };
    };

    homeManager =
      { ... }:
      {
        sops.age.keyFile = "/var/lib/sops-nix/key.txt";
      };
  };
}
