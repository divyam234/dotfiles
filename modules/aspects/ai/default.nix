
{ den, ... }:
{
  den.aspects.ai = {
    homeManager = { pkgs, ... }: {
      home.packages = with pkgs; [
        aider-chat
        opencode
      ];
    };
  };
}
