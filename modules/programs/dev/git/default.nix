{ pkgs, config, lib, ... }:

let
  cfg = config.mx.programs.dev.git;
in
{
  options.mx.programs.dev.git = {
    enable = lib.mkEnableOption "Enable Git with Large File Storage and the GitHub and GitLab clients";

    lfs = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Git Large File Storage. On by default because cloning a repository
        that uses it without the filter configured checks out pointer files
        instead of the real content, which reads as a corrupt working tree
        rather than as a missing tool.
      '';
    };

    defaultBranch = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "Value of init.defaultBranch written to /etc/gitconfig.";
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression "[ pkgs.git-filter-repo ]";
      description = "Additional version-control tooling to install alongside Git.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.git = {
      enable = true;
      lfs.enable = cfg.lfs;
      config.init.defaultBranch = cfg.defaultBranch;
    };

    environment.systemPackages = [
      pkgs.gh
      pkgs.glab
    ] ++ cfg.extraPackages;
  };
}
