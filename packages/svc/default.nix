{
  lib,
  makeWrapper,
  podman,
  rustPlatform,
  systemd,
}:

rustPlatform.buildRustPackage {
  pname = "svc";
  version = "0.1.0";
  src = lib.cleanSourceWith {
    src = ./.;
    filter = path: _type: baseNameOf path != "target";
  };
  cargoLock.lockFile = ./Cargo.lock;

  nativeBuildInputs = [ makeWrapper ];
  postInstall = ''
    wrapProgram $out/bin/svc \
      --prefix PATH : ${
        lib.makeBinPath [
          podman
          systemd
        ]
      }
  '';
}
