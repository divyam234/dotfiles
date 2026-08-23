{ den, ... }:
{
  den.aspects = {
    base.includes = [
      den.aspects.common
      den.aspects.sops
      den.aspects.boot-policy
      den.aspects.facter
      den.aspects.security-base
      den.aspects.tailscale
    ];

    workstation.includes = [
      den.aspects.desktop
      den.aspects.security-workstation
    ];

    server.includes = [
      den.aspects.development
      den.aspects.fail2ban
      den.aspects.security-server
    ];

    infra-host.includes = [
      den.aspects.base
      den.aspects.server
      den.aspects.integrated-home-manager
      den.aspects.oci-service
      den.aspects.requires-domain
      den.aspects.requires-secrets
      den.aspects.ghcr-auth
      den.aspects.caddy
      den.aspects.cloudflare-dns
    ];
  };
}
