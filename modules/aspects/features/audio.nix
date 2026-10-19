{ den, ... }:
{
  den.aspects.audio = { user, ... }: {
    nixos = {
      security.rtkit.enable = true;

      services.pipewire = {
        enable = true;
        pulse.enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        jack.enable = true;
      };

      users.users.${user.userName}.extraGroups = [ "audio" ];
    };
  };
}
