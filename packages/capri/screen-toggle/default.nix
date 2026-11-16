{
  stdenv,
  pkg-config,
  libdrm,
}:
stdenv.mkDerivation {
  pname = "capri-screen-toggle";
  version = "1.0.0";

  src = ./capri-screen-toggle.c;
  dontUnpack = true;
  dontConfigure = true;

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ libdrm ];

  buildPhase = ''
    runHook preBuild
    $CC -std=c11 -O2 -Wall -Wextra -Werror \
      $(pkg-config --cflags libdrm) \
      "$src" -o capri-screen-toggle \
      $(pkg-config --libs libdrm)
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 capri-screen-toggle "$out/bin/capri-screen-toggle"
    runHook postInstall
  '';

  meta.description = "Moto G10 Power Assistant key native DRM screen toggle";
  meta.platforms = [ "aarch64-linux" ];
}
