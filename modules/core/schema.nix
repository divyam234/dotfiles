{ den, ... }:
{
  den.schema.host =
    { lib, ... }:
    {
      options = {
        secretsFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Host-specific SOPS file consumed by aspects.";
        };

        domain = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = "bhunter.tech";
          description = "Primary public domain used by public services.";
        };
      };
    };
}
