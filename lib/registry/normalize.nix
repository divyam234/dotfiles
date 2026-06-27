_:
let
  supportedLinuxSystems = [
    "x86_64-linux"
    "aarch64-linux"
  ];

  defaultServiceRequirements = {
    aspects = [ ];
    services = [ ];
    secrets = false;
    domain = false;
  };

  normalizeService =
    name: value:
    {
      aspect = name;
      description = name;
      kind = "application";
      public = false;
      stateful = false;
      supportedSystems = supportedLinuxSystems;
      requires = defaultServiceRequirements;
    }
    // value
    // {
      requires = defaultServiceRequirements // (value.requires or { });
    };
in
{
  service = normalizeService;
  services = builtins.mapAttrs normalizeService;
}
