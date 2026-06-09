{ lib, ... }:
{
  # Keep host inventory simple while still using Den's canonical schema hook.
  #
  # Important: do not rely on `den.hosts.<host>.includes` directly here. In this
  # repo/version of Den, host-selected aspects must be injected from the host
  # schema. Removing this policy caused Netcup to build without OpenSSH,
  # Tailscale, Fail2ban, Podman, Caddy, and other NixOS service aspects.
  #
  # `selectedAspects` is declared in modules/bootstrap/schema.nix and is the
  # single inventory field that hosts use to select their profile/service stack.
  den.schema.host.includes = [
    (
      { host, ... }:
      let
        aspects = host.selectedAspects or [ ];
      in
      {
        includes = aspects;

        # Forward the host-selected aspect tree into attached users/homes.
        # This is required for per-user NixOS config such as
        # users.users.<name>.openssh.authorizedKeys and hashedPasswordFile.
        # Without this, `nixos-rebuild test` removes
        # /etc/ssh/authorized_keys.d/<user>, which breaks new SSH logins.
        provides.to-users = { ... }: {
          includes = aspects;
        };
      }
    )
  ];
}
