{ config, lib, ... }:

let
  cfg = config.mx.programs.desktop;
in
{
  imports = [
    ./onlyoffice
    ./libreoffice
    ./latex
  ];

  options.mx.programs.desktop = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.onlyoffice.enable || cfg.libreoffice.enable || cfg.latex.enable;
      defaultText = lib.literalExpression "any office module enabled";
      description = "Whether shared office config is active (auto: any office module enabled).";
    };
  };

  config = lib.mkIf cfg.enable {
    mx.fonts.enable = true;
  };
}
