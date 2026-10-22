{ pkgs, config, lib, ... }:

let
  cfg = config.mx.programs.creativity.krita;
in
{
  options.mx.programs.creativity.krita = {
    enable = lib.mkEnableOption "Enable Krita";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.krita;
      defaultText = lib.literalExpression "pkgs.krita";
      description = "Krita package to install.";
    };
  };

  config = lib.mkIf cfg.enable {
    mx.fonts.enable = true;
    environment.systemPackages = [ cfg.package ];
  };
}
