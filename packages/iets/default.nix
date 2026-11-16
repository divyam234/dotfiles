{
  fetchpatch,
  gitMinimal,
  installShellFiles,
  lib,
  pkg-config,
  rustPlatform,
  zstd,
}:
let
  src =
    (builtins.fetchTree {
      type = "github";
      owner = "numtide";
      repo = "iets";
      rev = "9157ca1a2a50c085bcd7fd0004d9ba71e2b7c1e0";
      narHash = "sha256-YFfGtsQEw5MQECnyIQqfMC1Wp51Tz/8oPD062mptAbE=";
    }).outPath;
  lock = builtins.readFile (src + "/Cargo.lock");
  dependencyAnchor = " \"protox\",\n \"ring\",";
  packageAnchor = "[[package]]\nname = \"regex\"\n";
  patchedLock =
    assert lib.hasInfix dependencyAnchor lock;
    assert lib.hasInfix packageAnchor lock;
    builtins.toFile "iets-Cargo.lock" (
      builtins.replaceStrings
        [
          dependencyAnchor
          packageAnchor
        ]
        [
          " \"protox\",\n \"rawzip\",\n \"ring\","
          ''
            [[package]]
            name = "rawzip"
            version = "0.5.2"
            source = "registry+https://github.com/rust-lang/crates.io-index"
            checksum = "ac9999039f74cd73c03158cddfe4362991703c74efe5ce5c8073026f80a5e48c"

            [[package]]
            name = "regex"
          ''
        ]
        lock
    );
in
rustPlatform.buildRustPackage {
  pname = "iets";
  version = lib.trim (builtins.readFile (src + "/VERSION"));
  inherit src;
  patches = [
    (fetchpatch {
      name = "iets-pr335-zip.patch";
      url = "https://github.com/numtide/iets/compare/000b20bc0e9335d4a851899f879e00d3fa5a5a75...28f1d5fc663392929cff4ebde8a927998d843963.diff";
      hash = "sha256-Z/6CQ1O0d6wK6OXWvk46LUNaS2VGXCAcp9QfDEX5Ib0=";
      excludes = [
        "Cargo.lock"
        "fuzz/Cargo.lock"
        "docs/explanation/flakes-and-sources.md"
      ];
    })
  ];
  cargoLock.lockFile = patchedLock;
  postPatch = ''
    cp ${patchedLock} Cargo.lock
  '';
  nativeBuildInputs = [
    installShellFiles
    pkg-config
  ];
  buildInputs = [ zstd ];
  IETS_FALLBACK_PATH = lib.makeBinPath [ gitMinimal ];
  cargoBuildFlags = [
    "--bin"
    "iets"
  ];
  cargoTestFlags = [
    "--lib"
    "fetch::spool::tests"
  ];
  postInstall = ''
    installShellCompletion \
      --bash src/cli/complete/iets.bash \
      --zsh src/cli/complete/iets.zsh \
      --fish src/cli/complete/iets.fish
  '';
  meta = {
    description = "Fast Nix evaluator with ZIP archive support from PR #335";
    homepage = "https://github.com/numtide/iets";
    license = lib.licenses.lgpl21Plus;
    mainProgram = "iets";
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
}
