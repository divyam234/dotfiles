{ pkgs }:
let
  # Source from linux-msm; this is a source build, never a RAMUI binary.
  pdMapper = pkgs.stdenv.mkDerivation {
    pname = "capri-pd-mapper";
    version = "unstable-2026";
    src = pkgs.fetchFromGitHub {
      owner = "linux-msm";
      repo = "pd-mapper";
      rev = "5ecd2fe926aca7abfe40724177f63b942cff3947";
      hash = "sha256-I5/N24KONtNRSub00Mqh1GoMHO2qQKTj/ts2N6DQdPc=";
    };
    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [
      pkgs.qrtr
      pkgs.xz
    ];
    postPatch = ''
      substituteInPlace pd-mapper.c \
        --replace-fail '"/lib/firmware/"' '"/run/current-system/firmware/"'
    '';
    installPhase = ''
      runHook preInstall
      install -Dm755 pd-mapper "$out/bin/pd-mapper"
      runHook postInstall
    '';
  };
  # Identical translate.c to the Capri RAMUI Wi-Fi scan success.
  # Rebase only firmware filesystem paths to the native NixOS system link.
  tqftpserv = pkgs.tqftpserv.overrideAttrs (old: {
    buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.xz ];
    postPatch = ''
      cp ${./tqftpserv-translate.c} translate.c
      cp ${./xz-decompress.c} xz-decompress.c
      cp ${./xz-decompress.h} xz-decompress.h
      cp ${./zstd-decompress.h} zstd-decompress.h
      substituteInPlace translate.c \
        --replace-fail '/lib/firmware/' '/run/current-system/firmware/'
    '';
  });
in
{
  inherit pdMapper tqftpserv;
}
