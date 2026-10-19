{ pkgs, config, lib, ... }:

let
  cfg = config.mx.programs.creativity.davinci-resolve-studio;
in
{
  options.mx.programs.creativity.davinci-resolve-studio = {
    enable = lib.mkEnableOption "Enable DaVinci Resolve Studio";
  };

  config = lib.mkIf cfg.enable {
    mx.hardware.gpu.compute.enable = true;
    mx.fonts.enable = true;
    environment.systemPackages = [ pkgs.davinci-resolve-studio ];
  };
}
