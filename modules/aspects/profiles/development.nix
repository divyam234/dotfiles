
{ den, ... }:
{
  den.aspects.development = {
    includes = [
      den.aspects.gpg
      den.aspects.zellij
      den.aspects.neovim
      den.aspects.attic
      den.aspects.modern-unix
      den.aspects.devtools
      den.aspects.container-tools
      den.aspects.database-tools
      den.aspects.network-tools
      den.aspects.ai
    ];
  };
}
