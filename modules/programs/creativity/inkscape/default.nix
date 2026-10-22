{ pkgs, config, lib, ... }:

let
  cfg = config.mx.programs.creativity.inkscape;
in
{
  options.mx.programs.creativity.inkscape = {
    enable = lib.mkEnableOption "Enable Inkscape";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.inkscape;
      defaultText = lib.literalExpression "pkgs.inkscape";
      description = "Inkscape package to install; pkgs.inkscape-with-extensions adds the bundled extension set.";
    };
  };

  config = lib.mkIf cfg.enable {
    mx.fonts.enable = true;
    environment.systemPackages = [ cfg.package ];
  };
}
