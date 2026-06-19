_:
let
  root = ../.;
  commonSopsFile = root + /secrets/common.yaml;
  missingCommon =
    name: throw "Common secret ${name} requested but ${toString commonSopsFile} does not exist.";
  missingHost =
    host: name:
    throw "Host ${host.name} requested host secret ${name} but does not set host.secretsFile.";
in
{
  secrets = {
    inherit commonSopsFile;

    common =
      name:
      if builtins.pathExists commonSopsFile then
        {
          sopsFile = commonSopsFile;
        }
      else
        missingCommon name;

    host =
      host: name:
      if host.secretsFile != null then
        {
          sopsFile = host.secretsFile;
        }
      else
        missingHost host name;
  };
}
