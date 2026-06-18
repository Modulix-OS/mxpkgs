{ config, pkgs-unstable, lib, ... }:

let
  cfg = config.mx.programs.games;
in
{
  options.mx.programs.games.umu.enable = lib.mkEnableOption "Install UMU";

  config = lib.mkIf cfg.umu.enable {
    environment.systemPackages = [ pkgs-unstable.umu-launcher ];
  };
}
