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
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.flatpak ];
      script = ''
        flatpak remote-add --if-not-exists flathub ${flathubRepo}
      '';
    };
  };
}
