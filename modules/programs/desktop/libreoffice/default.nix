{ config, lib, pkgs, ... }:

let
  cfg = config.mx.programs.desktop.libreoffice;

  mxDict = import ../../../../lib/mx-dictionaries.nix { inherit lib pkgs; };

  langs = config.mx.languages;
in
{
  options.mx.programs.desktop.libreoffice = {
    enable = lib.mkEnableOption "Install LibreOffice";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.libreoffice-fresh;
      defaultText = lib.literalExpression "pkgs.libreoffice-fresh";
      description = "LibreOffice package to install.";
    };
  };

  config = lib.mkIf cfg.enable {
    mx.fonts.enable = true;

    warnings = map
      (lang: "mx.programs.desktop.libreoffice: no hunspell dictionary for ${lang}, spell checking falls back to the LibreOffice default")
      (mxDict.unsupported langs);

    environment.systemPackages = [ cfg.package ] ++ mxDict.packages langs;

    environment.pathsToLink = [ "/share/hyphen" ];
  };
}
