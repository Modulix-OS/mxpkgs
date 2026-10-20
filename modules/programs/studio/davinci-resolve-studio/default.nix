{ pkgs, config, lib, ... }:

let
  cfg = config.mx.programs.studio.davinci-resolve-studio;
in
{
  options.mx.programs.studio.davinci-resolve-studio = {
    enable = lib.mkEnableOption "Enable DaVinci Resolve Studio";

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

  config = lib.mkIf cfg.enable {
    mx.hardware.gpu.compute.enable = true;
    mx.fonts.enable = true;
    environment.systemPackages = [ pkgs.davinci-resolve-studio ];

    environment.variables = lib.mkIf (cfg.ofxPlugins != [ ]) {
      OFX_PLUGIN_PATH = lib.concatStringsSep ";" (map toString cfg.ofxPlugins);
    };

    services.udev.extraRules = ''
      # Resolve Studio reads its licence from a Blackmagic USB dongle (vendor 096e)
      SUBSYSTEM=="usb", ATTR{idVendor}=="096e", MODE="0664", GROUP="users", TAG+="uaccess"
    '';
  };
}
