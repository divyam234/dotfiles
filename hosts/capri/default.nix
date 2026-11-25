{ den, lib, ... }:
{
  den.aspects.capri = {
    includes = [
      den.aspects.base
      den.aspects.server
      den.aspects.audio
      den.aspects.home-manager-policy
      den.aspects.librespot
      den.aspects.oci-service
      den.aspects.requires-domain
      den.aspects.caddy
      den.aspects.cloudflare-dns
      den.aspects.streamweave
      den.aspects.teldrive-native
    ];

    caddyRoutes.media = {
      host = "media.bhunter.tech";
      access = "tailnet";
      proxied = false;
      encode = false;
      cacheStatic = false;
      upstreams = [ "host.containers.internal:9000" ];
    };

    nixos =
      { containers, ... }:
      {
        imports = [
          ./buffyboard.nix
          ./hardware.nix
          ./image.nix
          ./modem-nv.nix
          ./screen-button.nix
          ./usb-ecm.nix
        ];
        system.stateVersion = "26.05";
        hardware.bluetooth = {
          enable = true;
          powerOnBoot = true;
        };
        services = {
          pipewire = {
            socketActivation = false;
            wireplumber.extraConfig."10-headless-bluetooth" = {
              "wireplumber.profiles".main."monitor.bluez.seat-monitoring" = "disabled";
            };
          };
          teldrive = {
            settings.http.address = lib.mkForce "0.0.0.0:8090";
          };
        };
        systemd = {
          user.services = {
            wireplumber.wantedBy = [ "default.target" ];
            pipewire-pulse.wantedBy = [ "default.target" ];
          };
          globalEnvironment.IETS_MAIN_STACK_MB = "2048";
        };
        networking.firewall.interfaces."br-${containers.networkName}".allowedTCPPorts = [
          9000
        ];
        users.users.bhunter.linger = true;
        environment.variables.IETS_MAIN_STACK_MB = "2048";
        zramSwap.enable = true;
        virtualisation.quadlet.networks.svc.networkConfig = {
          ipv6 = true;
          subnets = [ "fd89:ca91::/64" ];
        };
      };
  };
}
