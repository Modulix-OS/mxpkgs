{ pkgs, config, lib, ... }:

let
  cfg = config.mx.services.flatpak;

  flathubRepo = "https://dl.flathub.org/repo/flathub.flatpakrepo";
in
{
  options.mx.services.flatpak.enable = lib.mkEnableOption "Enable flatpak service";

  config = lib.mkIf cfg.enable {
    services.flatpak.enable = true;

    environment.sessionVariables.XDG_DATA_DIRS = [
      "/var/lib/flatpak/exports/share"
    ];

    systemd.services.flatpak-repo = {
      description = "Register the Flathub remote";
      wantedBy = [ "multi-user.target" ];
      requires = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      path = [ pkgs.flatpak ];
      serviceConfig = {
        Type = "oneshot";
        Restart = "on-failure";
        RestartSec = "30s";
      };
      script = ''
        flatpak remote-add --if-not-exists flathub ${flathubRepo}
      '';
    };
  };
}
