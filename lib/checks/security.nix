{
  homelab,
  ideapad,
  laptop,
  netcup,
}:
let
  hosts = [
    homelab
    ideapad
    laptop
    netcup
  ];
  hasAdGuardCertificate =
    host:
    builtins.any (
      certificate: builtins.baseNameOf (toString certificate) == "adguard.pem"
    ) host.security.pki.certificateFiles;
  hasEncryptedDNS =
    host:
    host.services.resolved.enable
    && host.services.resolved.settings.Resolve.DNSOverTLS == true
    && host.services.resolved.settings.Resolve.FallbackDNS == [ ]
    && host.services.resolved.settings.Resolve.Domains == [ "~." ]
    &&
      host.networking.nameservers == [
        "1.1.1.1#cloudflare-dns.com"
        "2606:4700:4700::1111#cloudflare-dns.com"
        "8.8.8.8#dns.google"
        "2001:4860:4860::8888#dns.google"
      ]
    && host.environment.etc."resolv.conf".source == "/run/systemd/resolve/stub-resolv.conf"
    && (
      !host.networking.networkmanager.enable || host.networking.networkmanager.dns == "systemd-resolved"
    );
in
assert builtins.all hasAdGuardCertificate hosts;
assert builtins.all hasEncryptedDNS hosts;
true
