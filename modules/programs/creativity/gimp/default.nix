{ pkgs, config, lib, ... }:

let
  cfg = config.mx.programs.creativity.gimp;
in
{
  options.mx.programs.creativity.gimp = {
    enable = lib.mkEnableOption "Enable GIMP";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.gimp;
      defaultText = lib.literalExpression "pkgs.gimp";
      description = "GIMP package to install; set to pkgs.gimp-with-plugins for the bundled plugin set.";
    };
  };

  config = lib.mkIf cfg.enable {
    mx.fonts.enable = true;
    environment.systemPackages = [ cfg.package ];
  };
}
