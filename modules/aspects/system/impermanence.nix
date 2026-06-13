{ inputs, den, ... }:
{
  den.aspects.impermanence = {
    nixos =
      { ... }:
      {
        imports = [ inputs.impermanence.nixosModules.impermanence ];
        environment.persistence."/persist" = {
          hideMounts = true;
          directories = [
            "/etc/nixos"
            "/var/lib/NetworkManager"
            "/var/lib/bluetooth"
            "/var/lib/systemd"
            "/var/lib/tailscale"
            "/home/bhunter/.local/state/container-services"
            "/root"
          ];
          files = [
            "/etc/machine-id"
            "/etc/ssh/ssh_host_ed25519_key"
            "/etc/ssh/ssh_host_ed25519_key.pub"
          ];
        };
      };
  };
}
