{ pkgs, config, lib, ... }:

let
  cfg = config.mx.programs.creativity.bambu-studio;
in
{
  options.mx.programs.creativity.bambu-studio = {
    enable = lib.mkEnableOption "Enable Bambu Studio slicer";
  };

  config = lib.mkIf cfg.enable {
    mx.fonts.enable = true;
    environment.systemPackages = [ pkgs.bambu-studio ];
  };
}
