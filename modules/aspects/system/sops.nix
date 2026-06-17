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
      { config, ... }:
      {
        sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
      };
  };
}
