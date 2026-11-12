{
  runCommand,
  gnutar,
  xz,
}:

# The original Motorola firmware bytes are stored as a maximally compressed
# source archive, not expanded in Git. No private modem NV snapshots included.
runCommand "capri-motorola-firmware"
  {
    nativeBuildInputs = [
      gnutar
      xz
    ];
  }
  ''
    mkdir -p "$out"
    tar -xJf ${./capri-motorola-verified.tar.xz} -C "$out"
  ''
