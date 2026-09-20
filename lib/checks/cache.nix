{
  homelab,
  ideapad,
  laptop,
  netcup,
}:
let
  hosts = [
    laptop
    ideapad
    homelab
    netcup
  ];
  substituter = "http://127.0.0.1:7745";
  publicKey = "nix-cache-1:833kjCWb6yhgpaUIez65hOJBJUZDkns+ybXW/WJMsYI=";
  lantianSubstituter = "https://attic.xuyh0120.win/lantian";
  lantianPublicKey = "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc=";
  has = value: values: builtins.any (candidate: candidate == value) values;
  all = predicate: builtins.all predicate hosts;
in
assert all (host: has substituter host.nix.settings.substituters);
assert all (host: has publicKey host.nix.settings.trusted-public-keys);
assert all (host: !has lantianSubstituter host.nix.settings.substituters);
assert all (host: !has lantianPublicKey host.nix.settings.trusted-public-keys);
assert all (host: builtins.hasAttr "nix-cache-proxy" host.systemd.services);
assert all (host: host.systemd.services.nix-cache-proxy.wantedBy == [ "multi-user.target" ]);
assert all (host: host.systemd.services.nix-cache-proxy.serviceConfig.DynamicUser);
assert all (
  host:
  builtins.match ".*nix-cache serve.*--block-size 33554432.*--max-downloads 8.*" host.systemd.services.nix-cache-proxy.serviceConfig.ExecStart
  != null
);
true
