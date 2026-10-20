{ config, lib, ... }:

let
  gpu = config.mx.hardware.gpu;
  cfg = gpu.hybrid;
in
{
  options.mx.hardware.gpu.hybrid.enable = lib.mkOption {
    type = lib.types.bool;
    default = gpu.dedicated.vendor != null && gpu.integrated.vendor != null;
    defaultText = lib.literalMD "true when both GPU slots declare a vendor";
    description = ''
      Hybrid laptop handling: runs switcheroo-control so that desktop entries
      carrying PrefersNonDefaultGPU start on the discrete GPU. Without the
      service the key is inert on both GNOME and Plasma.
    '';
  };

  config = lib.mkIf cfg.enable {
    services.switcherooControl.enable = lib.mkDefault true;
  };
}
