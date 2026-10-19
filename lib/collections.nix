{ lib }:
{
  findDuplicates =
    list:
    lib.pipe list [
      (lib.groupBy (x: x))
      (lib.filterAttrs (_: v: builtins.length v > 1))
      builtins.attrNames
    ];
}
