{ pkgs, config, lib, ... }:

let
  cfg = config.mx.programs.creativity.davinci-resolve;
  studioEnabled = config.mx.programs.creativity.davinci-resolve-studio.enable;
in
{
  options.mx.programs.creativity.davinci-resolve = {
    enable = lib.mkEnableOption "Enable DaVinci Resolve";
  };

  config = lib.mkIf (cfg.enable && !studioEnabled) {
    mx.hardware.gpu.compute.enable = true;
    mx.fonts.enable = true;
    environment.systemPackages = [ pkgs.davinci-resolve ];
  };
}
