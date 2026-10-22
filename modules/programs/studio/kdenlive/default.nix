{ pkgs, config, lib, ... }:

let
  cfg = config.mx.programs.studio.kdenlive;
in
{
  options.mx.programs.studio.kdenlive = {
    enable = lib.mkEnableOption "Enable Kdenlive";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.kdePackages.kdenlive;
      defaultText = lib.literalExpression "pkgs.kdePackages.kdenlive";
      description = "Kdenlive package to install.";
    };
  };

  config = lib.mkIf cfg.enable {
    mx.programs._studio.enable = true;
    mx.fonts.enable = true;
    environment.systemPackages = [ cfg.package ];
  };
}
