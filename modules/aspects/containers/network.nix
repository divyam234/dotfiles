{ den, ... }:
{
  den.aspects.container-network = {
    nixos = { pkgs, lib, ... }: {
      systemd.services."podman-network-${lib.dot.containerNetwork}" = {
        description = "Create shared Podman network ${lib.dot.containerNetwork}";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        path = [ pkgs.podman ];
        script = ''
          podman network exists ${lib.dot.containerNetwork} || podman network create ${lib.dot.containerNetwork}
        '';
      };
    };
  };
}
