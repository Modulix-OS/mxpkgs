{ lib, config, ... }:

let
  cfg = config.mx.core.sound;
in
{
  options.mx.core.sound = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable sound fonctionnality";
    };
  };

  config = lib.mkIf (!config.mx.mode.server.enable && cfg.enable) (
    lib.mkMerge [
    {
      services.pulseaudio.enable = false;
      services.pipewire = {
        enable = true;
        alsa = {
          enable = true;
          support32Bit = true;
        };
        pulse.enable = true;
        jack.enable = true;

        # Based on GLF OS configuration
        extraConfig.pipewire = {
          "92-low-latency" = {
            "context.properties" = {
              "default.clock.rate" = 48000;
              "default.clock.quantum" = 256;
              "default.clock.min-quantum" = 256;
              "default.clock.max-quantum" = 256;
            };
          };
        };
        wireplumber.extraConfig = {
          "10-disable-camera" = {
            "wireplumber.profiles" = {
              main = {
                "monitor.libcamera" = "disabled";
              };
            };
          };
        };
      };
    }
  ]);
}
