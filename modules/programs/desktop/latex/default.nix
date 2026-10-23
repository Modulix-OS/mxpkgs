{ config, lib, pkgs, ... }:

let
  cfg = config.mx.programs.desktop.latex;

  mxDict = import ../../../../lib/mx-dictionaries.nix { inherit lib pkgs; };

  langs = config.mx.languages;
in
{
  options.mx.programs.desktop.latex = {
    enable = lib.mkEnableOption "Install the LaTeX document toolchain";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.texliveFull;
      defaultText = lib.literalExpression "pkgs.texliveFull";
      description = ''
        TeX Live distribution to install. The full scheme is the default so
        that any document compiles without hunting for a missing package; set
        it to a smaller scheme such as pkgs.texliveMedium to save disk space.
      '';
    };

    editor = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.texstudio;
      defaultText = lib.literalExpression "pkgs.texstudio";
      description = ''
        LaTeX editor installed alongside the distribution; null to install
        none. pkgs.texstudio already carries the GSettings schemas it needs to
        start outside its own desktop, see modulixos/package-fix.nix.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    mx.fonts.enable = true;

    warnings = map
      (lang: "mx.programs.desktop.latex: no hunspell dictionary for ${lang}, spell checking in the editor falls back to its default")
      (mxDict.unsupported langs);

    environment.systemPackages =
      [ cfg.package ]
      ++ lib.optional (cfg.editor != null) cfg.editor
      ++ mxDict.packages langs;

    environment.pathsToLink = [ "/share/hyphen" ];
  };
}
