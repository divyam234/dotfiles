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
in
assert builtins.all hasAdGuardCertificate hosts;
true
