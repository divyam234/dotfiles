{
  gitMinimal,
  installShellFiles,
  lib,
  pkg-config,
  rustPlatform,
  stdenv,
  stdenvAdapters,
  zstd,
}:
let
  src =
    (builtins.fetchTree {
      type = "github";
      owner = "numtide";
      repo = "iets";
      rev = "fb2a374830e8c644e7c29b546ad0e6198ba2d603";
      narHash = "sha256-MgGPeMQ9ky9G1uEIk8DA7xJcadOVipoSYrDtaz2le34=";
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
(rustPlatform.buildRustPackage.override {
  stdenv = stdenvAdapters.useMoldLinker stdenv;
})
  {
    pname = "iets";
    version = lib.trim (builtins.readFile (src + "/VERSION"));
    inherit src;
    patches = [
      ./zip.patch
    ];
    cargoLock.lockFile = patchedLock;
    postPatch = ''
      cp ${patchedLock} Cargo.lock
      # Resolve once so the evaluator thread, demand fiber and reservation
      # accounting use the same size. Unset preserves the upstream 4 GiB.
      substituteInPlace src/parallel/fiber.rs \
        --replace-fail 'pub const MAIN_STACK: usize = 4 << 30;' '
      pub static MAIN_STACK: std::sync::LazyLock<usize> = std::sync::LazyLock::new(|| {
          let Some(value) = std::env::var_os("IETS_MAIN_STACK_MB") else {
              return 4 << 30;
          };
          let mib = value
              .to_str()
              .and_then(|s| s.parse::<usize>().ok())
              .filter(|n| (16..=4096).contains(n));
          match mib {
              Some(n) => n << 20,
              None => {
                  eprintln!("IETS_MAIN_STACK_MB must be an integer from 16 to 4096 (MiB)");
                  std::process::exit(2);
              }
          }
      });' \
        --replace-fail '.saturating_add(MAIN_STACK)' '.saturating_add(*MAIN_STACK)' \
        --replace-fail 'DEFAULT_STACK * 1023 + MAIN_STACK' 'DEFAULT_STACK * 1023 + *MAIN_STACK'
      substituteInPlace src/cli/run.rs src/api/concurrent_eval.rs \
        --replace-fail '.stack_size(MAIN_STACK)' '.stack_size(*MAIN_STACK)'
      substituteInPlace src/parallel/sched.rs \
        --replace-fail 'self.new_slot(fiber::MAIN_STACK, || user)' \
          'self.new_slot(*fiber::MAIN_STACK, || user)'
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
    doCheck = false;
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
