{ den, ... }:
{
  den.aspects.audio.nixos =
    { host, ... }:
    {
      security.rtkit.enable = true;

      services.pipewire = {
        enable = true;
        pulse.enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        jack.enable = true;
      };

      users.users.${host.user}.extraGroups = [ "audio" ];
    };
}
