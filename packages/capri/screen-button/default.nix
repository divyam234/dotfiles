{ lib, stdenv }:
stdenv.mkDerivation {
  pname = "capri-screen-button";
  version = "1.0";
  src = ./.;
  strictDeps = true;

  buildPhase = ''
    runHook preBuild
    $CC -std=c11 -O2 -Wall -Wextra -Werror screen-button.c -o capri-screen-button
    runHook postBuild
  '';

  doCheck = stdenv.buildPlatform.canExecute stdenv.hostPlatform;
  checkPhase = ''
    runHook preCheck
    $CC -std=c11 -O2 -Wall -Wextra -Werror test-screen-button.c -o test-screen-button
    ./test-screen-button
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 capri-screen-button "$out/bin/capri-screen-button"
    runHook postInstall
  '';

  meta = {
    description = "Capri assistant-button display toggle for the text console and Buffyboard";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.linux;
    mainProgram = "capri-screen-button";
  };
}
