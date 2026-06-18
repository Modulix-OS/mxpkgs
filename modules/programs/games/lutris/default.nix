{ config, pkgs-unstable, lib, ... }:

let
  cfg = config.mx.programs.games;
in
{
  options.mx.programs.games.lutris.enable = lib.mkEnableOption "Install Lutris";

  config = lib.mkIf cfg.lutris.enable {
    environment.systemPackages = [ pkgs-unstable.lutris ];
  };
}
