{ den, ... }:
{
  den.aspects.sops = {
    nixos = { ... }: {
      sops = {
        defaultSopsFormat = "yaml";
        age = {
          sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
          keyFile = "/var/lib/sops-nix/key.txt";
          generateKey = true;
        };
      };
    };

    homeManager = { config, ... }: {
      sops = {
        age = {
          generateKey = true;
          keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
        };
      };
    };
  };
}
