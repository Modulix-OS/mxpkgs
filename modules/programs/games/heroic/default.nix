{ config, pkgs-unstable, lib, ... }:

let
  cfg = config.mx.programs.games;
in
{
  options.mx.programs.games.heroic.enable = lib.mkEnableOption "Install Heroic";

  config = lib.mkIf cfg.heroic.enable {
    environment.systemPackages = [ pkgs-unstable.heroic ];
  };
}
