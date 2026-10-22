{ pkgs, config, lib, ... }:

let
  cfg = config.mx.programs.games.vr;
in
{
  options.mx.programs.games.vr = {
    enable = lib.mkEnableOption "Enable virtual reality support (ALVR, SteamVR runtime, headset udev rules)";

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Open the ports ALVR streams over. A standalone headset reaches the
        machine over the local network, so without this the client never finds
        the server.
      '';
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression "[ pkgs.sidequest ]";
      description = "Additional VR tooling to install alongside ALVR.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.alvr = {
      enable = true;
      openFirewall = cfg.openFirewall;
    };

    mx.programs.games.steam.enable = lib.mkMxDefault true;

    hardware.steam-hardware.enable = lib.mkMxDefault true;

    environment.systemPackages = [ pkgs.opencomposite ] ++ cfg.extraPackages;

    environment.sessionVariables = {
      XR_RUNTIME_JSON = lib.mkMxDefault "${pkgs.alvr}/share/openxr/1/openxr_alvr.json";
    };
  };
}
