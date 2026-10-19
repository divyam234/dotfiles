{
  lib,
  installShellFiles,
  makeWrapper,
  podman,
  rustPlatform,
  systemd,
}:

rustPlatform.buildRustPackage {
  pname = "svc";
  version = (lib.importTOML ./Cargo.toml).package.version;
  src = lib.cleanSourceWith {
    src = ./.;
    filter = path: _type: baseNameOf path != "target";
  };
  cargoLock.lockFile = ./Cargo.lock;

  nativeBuildInputs = [
    installShellFiles
    makeWrapper
  ];
  postInstall = ''
    installShellCompletion --cmd svc \
      --bash <($out/bin/svc completions bash) \
      --fish <($out/bin/svc completions fish) \
      --zsh <($out/bin/svc completions zsh)
    $out/bin/svc man > svc.1
    installManPage svc.1

    wrapProgram $out/bin/svc \
      --prefix PATH : ${
        lib.makeBinPath [
          podman
          systemd
        ]
      }
  '';
}
