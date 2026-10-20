{ pkgs, config, lib, ... }:

let
  cfg = config.mx.programs.studio.davinci-resolve;
  studioEnabled = config.mx.programs.studio.davinci-resolve-studio.enable;

  resolveDesktop = pkgs.callPackage ../../../../lib/prefers-dgpu-desktop.nix {
    package = pkgs.davinci-resolve;
    desktopIds = [ "davinci-resolve" "blackmagicraw-player" "blackmagicraw-speedtest" ];
  };

  mp4ToMov = import ../../../../pkgs/mx-mp4-to-mov.nix { inherit pkgs; };
in
{
  options.mx.programs.studio.davinci-resolve = {
    enable = lib.mkEnableOption "Enable DaVinci Resolve";

    ofxPlugins = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = ''
        OpenFX plugin packages exposed to Resolve through OFX_PLUGIN_PATH, since
        the usual /usr/OFX/Plugins location does not exist on NixOS. Paths are
        traversed recursively, so pointing at the package root is enough.
      '';
    };
  };

  config = lib.mkIf (cfg.enable && !studioEnabled) {
    mx.hardware.gpu.compute.enable = true;
    mx.fonts.enable = true;
    environment.systemPackages = [
      pkgs.davinci-resolve
      (lib.hiPrio resolveDesktop)
      mp4ToMov
    ];

    environment.variables = lib.mkIf (cfg.ofxPlugins != [ ]) {
      OFX_PLUGIN_PATH = lib.concatStringsSep ";" (map toString cfg.ofxPlugins);
    };
  };
}
