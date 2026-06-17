_:
let
  supportedLinuxSystems = [
    "x86_64-linux"
    "aarch64-linux"
  ];

  defaultServiceRequirements = {
    features = [ ];
    services = [ ];
    secrets = false;
    domain = false;
  };

  normalizeFeature =
    name: value:
    {
      aspect = name;
      description = name;
      requires = [ ];
      conflicts = [ ];
      supportedSystems = supportedLinuxSystems;
    }
    // value;

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
  feature = normalizeFeature;
  service = normalizeService;
  features = builtins.mapAttrs normalizeFeature;
  services = builtins.mapAttrs normalizeService;
}
