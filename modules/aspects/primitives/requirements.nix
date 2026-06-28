{ den, ... }:
{
  den.aspects = {
    requires-domain.nixos =
      { host, ... }:
      let
        domain = host.domain or null;
        placeholders = [
          "example.com"
          "example.org"
          "example.net"
          "localhost"
        ];
      in
      {
        assertions = [
          {
            assertion = domain != null && !(builtins.elem domain placeholders);
            message = "This host composition requires a non-placeholder host.domain.";
          }
        ];
      };

    requires-secrets.nixos =
      { host, ... }:
      {
        assertions = [
          {
            assertion = (host.secretsFile or null) != null;
            message = "This host composition requires host.secretsFile.";
          }
        ];
      };
  };
}
