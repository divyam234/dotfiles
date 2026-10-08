{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "gecit";
  version = "0.2.1";

  src = fetchFromGitHub {
    owner = "boratanrikulu";
    repo = "gecit";
    rev = "v${version}";
    hash = "sha256-ee0d2/5C7CwjStHqqXullQkgDcBV9Cq/eBJ6WTLlXIc=";
  };

  # Userspace-only exclusion support: --exclude flag + exclude_cidrs key.
  # BPF objects are prebuilt upstream; Go bindings for them ship in the patch,
  # so the build is pure Go (no gobee/clang needed).
  patches = [ ./exclude-cidrs.patch ];

  vendorHash = "sha256-YtQt9TOugMQyIZcjMd92e9Nzkc7D8bdBoEPHA4XzMT8=";
  proxyVendor = true;

  subPackages = [ "cmd/gecit" ];

  env.CGO_ENABLED = 0;

  ldflags = [
    "-s"
    "-w"
    "-X github.com/boratanrikulu/gecit/cmd/gecit/app.version=${version}"
  ];

  meta = {
    description = "DPI bypass via eBPF sock_ops + fake TLS ClientHello";
    homepage = "https://github.com/boratanrikulu/gecit";
    license = lib.licenses.gpl3Only;
    maintainers = [ ];
    mainProgram = "gecit";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
