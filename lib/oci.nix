{ lib }:
let
  containerNetwork = "svc";
  containerDataRoot = "/var/lib/containers";
  containerSecretDir = "/run/secrets/container-env";
in
rec {
  inherit containerNetwork containerDataRoot containerSecretDir;

  containerDataDir = name: "${containerDataRoot}/${name}";
  containerEnvFile = name: "${containerSecretDir}/${name}.env";

  mkServiceDirRules =
    names:
    [ "d ${containerDataRoot} 0750 root root -" ]
    ++ map (name: "d ${containerDataRoot}/${name} 0750 root root -") names;
}
