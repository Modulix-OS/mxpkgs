{ pkgs, config, lib, ... }:

let
  cfg = config.mx.programs.studio.davinci-resolve;
  studioEnabled = config.mx.programs.studio.davinci-resolve-studio.enable;
  waylandDesktop = builtins.elem config.mx.desktop [ "gnome" "plasma" ];
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
    environment.systemPackages = [ pkgs.davinci-resolve ];

    environment.variables = lib.mkIf (cfg.ofxPlugins != [ ]) {
      OFX_PLUGIN_PATH = lib.concatStringsSep ";" (map toString cfg.ofxPlugins);
    };

    warnings = lib.optional waylandDesktop ''
      DaVinci Resolve cannot run on a native Wayland session (qtwayland version
      mismatch, NixOS/nixpkgs#341634). Launch it as
      `QT_QPA_PLATFORM=xcb davinci-resolve` to force XWayland.
    '';
  };
}
