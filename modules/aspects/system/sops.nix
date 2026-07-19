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
      { pkgs, ... }:
      {
        home.packages = [ pkgs.sops ];
        sops.age.keyFile = "/var/lib/sops-nix/key.txt";
      };
  };
}
