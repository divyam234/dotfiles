{
  fetchFromGitLab,
  lib,
  libevdev,
  libinput,
  libxkbcommon,
  meson,
  ninja,
  pkg-config,
  stdenv,
}:
stdenv.mkDerivation {
  pname = "buffyboard";
  version = "unstable-2023-11-20";

  # Same source revision used by chayleaf/dotfiles for the OnePlus 6.
  src = fetchFromGitLab {
    owner = "postmarketOS";
    repo = "buffybox";
    rev = "14b30c60183d98e8d0b4dadf66198e08badf631e";
    hash = "sha256-9wLuTAqYoFl+IAR1ixp0nHwh6jBWl+1jDPhhxqE+LHQ=";
    fetchSubmodules = true;
  };

  # Upstream tracks this at https://gitlab.com/postmarketOS/buffybox/-/issues/1.
  hardeningDisable = [ "fortify3" ];
  sourceRoot = "source/buffyboard";

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
  ];

  buildInputs = [
    libevdev
    libinput
    libxkbcommon
  ];

  meta = {
    description = "Touchscreen on-screen keyboard for the Linux framebuffer";
    homepage = "https://gitlab.com/postmarketOS/buffybox/-/tree/master/buffyboard";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "buffyboard";
  };
}
