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

        # User/Home Manager projection is handled by den._.host-aspects on the
        # bhunter user aspect. Do not also forward the whole host aspect tree via
        # provides.to-users here; doing both can make desktop-only Home Manager
        # modules leak into non-desktop hosts during flake evaluation.
      }
    )
  ];
}
