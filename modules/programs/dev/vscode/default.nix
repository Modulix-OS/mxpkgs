{ pkgs, config, lib, ... }:

let
  cfg = config.mx.programs.dev.vscode;
in
{
  options.mx.programs.dev.vscode = {
    enable = lib.mkEnableOption "Enable Visual Studio Code";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.vscode-fhs;
      defaultText = lib.literalExpression "pkgs.vscode-fhs";
      description = ''
        Visual Studio Code package to install. The FHS variant is the default
        because most marketplace extensions ship prebuilt native binaries
        (clangd, debug adapters, language servers) that cannot run against the
        Nix store layout; use pkgs.vscode for the plain build.
      '';
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression "[ pkgs.nixd pkgs.nixfmt-rfc-style ]";
      description = "Language servers and formatters installed next to the editor.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ] ++ cfg.extraPackages;

    mx.programs.dev.git.enable = lib.mkMxDefault true;
  };
}
