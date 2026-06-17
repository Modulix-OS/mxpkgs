{ config, lib, pkgs, ... }:

let
  cfg = config.mx.hardware.gpu;
in {

  config = {
    hardware.graphics = {
      enable = true;

      extraPackages = with pkgs;
        lib.optionals (cfg.vendor == "intel") [
          intel-media-driver   # Modern intel
          libvdpau-va-gl
        ]
        ++ lib.optionals (cfg.vendor == "nvidia") [
          vaapiVdpau
          libvdpau-va-gl
        ];
    };

    environment.sessionVariables = lib.mkMerge [
      (lib.mkIf (cfg.vendor == "intel" && cfg.generation == "modern") {
        LIBVA_DRIVER_NAME = "iHD";
      })
      (lib.mkIf (cfg.vendor == "intel" && cfg.generation == "legacy") {
        LIBVA_DRIVER_NAME = "i965";
      })
      (lib.mkIf (cfg.vendor == "nvidia") {
        LIBVA_DRIVER_NAME     = "nvidia";
        MOZ_DISABLE_RDD_SANDBOX = "1";  # Firefox VAAPI
      })
    ];
  };
}
