{ config, lib, pkgs, ... }:

let
  cfg = config.mx.programs.desktop.onlyoffice;

  withSystemFonts = pkgs.buildFHSEnv (cfg.package.args // {
    targetPkgs = p: cfg.package.args.targetPkgs p ++ config.fonts.packages;
  });
in
{
  options.mx.programs.desktop.onlyoffice = {
    enable = lib.mkEnableOption "Install ONLYOFFICE Desktop Editors";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.onlyoffice-desktopeditors;
      defaultText = lib.literalExpression "pkgs.onlyoffice-desktopeditors";
      description = ''
        ONLYOFFICE package to install. It must be a buildFHSEnv derivation: the
        module rebuilds its FHS environment to add the system fonts, which the
        editors only pick up from /usr/share/fonts.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    mx.fonts.enable = true;

    environment.systemPackages = [ withSystemFonts ];
  };
}
