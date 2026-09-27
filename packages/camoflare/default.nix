{
  lib,
  buildGoModule,
}:
let
  version = "0.1.0";
in
buildGoModule {
  pname = "camoflare";
  inherit version;
  src = lib.cleanSourceWith {
    src = ./.;
    filter = path: _type: baseNameOf path != "result" && baseNameOf path != "result-1";
  };
  # Stdlib only: no vendored dependencies to hash.
  vendorHash = null;
  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
  ];
  meta = with lib; {
    description = "FlareSolverr-compatible challenge-solving proxy backed by Camofox";
    homepage = "https://github.com/jo-inc/camofox-browser";
    license = licenses.mit;
    mainProgram = "camoflare";
    platforms = platforms.linux;
  };
}
