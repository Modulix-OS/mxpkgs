{ config, lib, ... }:

let
  cfg = config.mx.programs.desktop;
in
{
  imports = [
    ./onlyoffice
    ./libreoffice
  ];

  options.mx.programs.desktop = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.onlyoffice.enable || cfg.libreoffice.enable;
      defaultText = lib.literalExpression "any office suite enabled";
      description = "Whether shared office config is active (auto: any suite enabled).";
    };
  };

  config = lib.mkIf cfg.enable {
    mx.fonts.enable = true;
  };
}
