{
  buildGoModule,
  lib,
}:

buildGoModule {
  pname = "zenproxy";
  version = "0.1.0";
  src = ./.;
  vendorHash = null;

  meta = {
    description = "OpenCode Zen proxy with NordVPN egress rotation";
    license = lib.licenses.mit;
    mainProgram = "zenproxy";
  };
}
