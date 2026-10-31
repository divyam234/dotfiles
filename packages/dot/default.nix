{
  lib,
  buildGoModule,
  writeText,
  runCommand,
  makeWrapper,
  installShellFiles,
  fish,
  git,
  nix,
  nh,
  openssh,
  hosts ? [ ],
  homes ? [ ],
}:
let
  package = buildGoModule {
    pname = "dot";
    version = "0.1.0";
    src = lib.cleanSource ./.;
    vendorHash = "sha256-7K17JaXFsjf163g5PXCb5ng2gYdotnZ2IDKk8KFjNj0=";
    postPatch = ''
      cp ${writeText "dot-targets.json" (builtins.toJSON { inherit hosts homes; })} targets.json
    '';
    nativeBuildInputs = [
      makeWrapper
      installShellFiles
    ];
    postInstall = ''
      installShellCompletion --cmd dot --fish <($out/bin/dot completion fish)
      wrapProgram $out/bin/dot --prefix PATH : ${
        lib.makeBinPath [
          git
          nix
          nh
          openssh
        ]
      }
    '';
    passthru.tests.behavior = runCommand "dot-completion-tests" { nativeBuildInputs = [ fish ]; } ''
      mkdir completion-dir
      touch not-a-command
      # Runtime tools must never be called during completion.
      mkdir stubs
      ln -s ${package}/bin/.dot-wrapped stubs/dot
      for tool in nix nh git ssh; do
        printf '#!%s\necho unexpected-tool-call >> "%s"\nexit 1\n' \
          "$SHELL" "$PWD/tool-calls" > stubs/$tool
        chmod +x stubs/$tool
      done
      export PATH=$PWD/stubs:$PATH
      fish --no-config ${./tests.fish} \
        ${package}/share/fish/vendor_completions.d/dot.fish \
        ${lib.escapeShellArg (lib.head (hosts ++ [ "" ]))} \
        ${lib.escapeShellArg (lib.head (homes ++ [ "" ]))}
      test ! -e tool-calls
      touch $out
    '';
    meta = {
      description = "Manage this dotfiles flake with context-aware shell completions";
      mainProgram = "dot";
    };
  };
in
package
