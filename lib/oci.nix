{ lib }:
let
  containerNetwork = "svc";
  containerDataRoot = "/var/lib/containers";
  containerSecretDir = "/run/secrets/container-env";
in
rec {
  inherit containerNetwork containerDataRoot containerSecretDir;

  containerName = name: name;
  containerDataDir = name: "${containerDataRoot}/${name}";
  containerEnvFile = name: "${containerSecretDir}/${name}.env";

  mkContainerDeps =
    name: dependencies:
    let
      networkUnit = "podman-network-${containerNetwork}.service";
      dependencyUnits = map (dependency: "podman-${dependency}.service") dependencies;
      units = [ networkUnit ] ++ dependencyUnits;
    in
    {
      after = units ++ [ "network-online.target" ];
      wants = [ "network-online.target" ];
      requires = units;
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Restart = lib.mkDefault "always";
        RestartSec = lib.mkDefault "10s";
      };
    };

  mkContainerSecretDeps =
    name: dependencies:
    let
      base = mkContainerDeps name dependencies;
    in
    base
    // {
      after = base.after ++ [ "sops-install-secrets.service" ];
      requires = base.requires ++ [ "sops-install-secrets.service" ];
    };

  mkServiceDirRules =
    names:
    [ "d ${containerDataRoot} 0750 root root -" ]
    ++ map (name: "d ${containerDataRoot}/${name} 0750 root root -") names;

  mkOci =
    name: args:
    let
      networkMode = args.networkMode or containerNetwork;
      cmd =
        if args ? cmd then
          args.cmd
        else if args ? command then
          args.command
        else
          null;
    in
    {
      image = args.image;
      autoStart = args.autoStart or true;
      extraOptions = (args.extraOptions or [ ]) ++ [ "--network=${networkMode}" ];
    }
    // lib.optionalAttrs (args ? environment) { inherit (args) environment; }
    // lib.optionalAttrs (args ? environmentFiles) { inherit (args) environmentFiles; }
    // lib.optionalAttrs (cmd != null) { inherit cmd; }
    // lib.optionalAttrs (args ? entrypoint) { inherit (args) entrypoint; }
    // lib.optionalAttrs (args ? volumes) { inherit (args) volumes; }
    // lib.optionalAttrs (args ? ports) { inherit (args) ports; }
    // lib.optionalAttrs (args ? dependsOn) { inherit (args) dependsOn; }
    // lib.optionalAttrs (args ? labels) { inherit (args) labels; };
}
