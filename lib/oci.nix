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
      after = units;
      requires = units;
      wantedBy = [ "multi-user.target" ];
    };

  mkServiceDirRules =
    names:
    [ "d ${containerDataRoot} 0750 root root -" ]
    ++ map (name: "d ${containerDataRoot}/${name} 0750 root root -") names;

  mkOci =
    name: args:
    let
      networkMode = args.networkMode or containerNetwork;
    in
    {
      image = args.image;
      autoStart = args.autoStart or true;
      extraOptions = (args.extraOptions or [ ]) ++ [ "--network=${networkMode}" ];
    }
    // lib.optionalAttrs (args ? environment) { inherit (args) environment; }
    // lib.optionalAttrs (args ? environmentFiles) { inherit (args) environmentFiles; }
    // lib.optionalAttrs (args ? command) { inherit (args) command; }
    // lib.optionalAttrs (args ? entrypoint) { inherit (args) entrypoint; }
    // lib.optionalAttrs (args ? volumes) { inherit (args) volumes; }
    // lib.optionalAttrs (args ? ports) { inherit (args) ports; }
    // lib.optionalAttrs (args ? dependsOn) { inherit (args) dependsOn; }
    // lib.optionalAttrs (args ? labels) { inherit (args) labels; };
}
