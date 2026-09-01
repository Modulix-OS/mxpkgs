{ pkgs, config, lib, ... }:

let
  cfg = config.mx.services.flatpak;
  flatpakApp = import ./app.nix { inherit lib; enableApp = cfg.enable; };

  flatpakSync = pkgs.writeShellApplication {
    name = "flatpak-sync";
    runtimeInputs = [ pkgs.flatpak ];
    text = ''
      wanted=(${lib.escapeShellArgs cfg.apps})
      removed=(${lib.escapeShellArgs cfg.removedApps})

      for app in ''${removed[@]+"''${removed[@]}"}; do
        if flatpak info --user "$app" >/dev/null 2>&1; then
          flatpak uninstall --user -y --noninteractive "$app"
        fi
      done

      if [ ''${#wanted[@]} -eq 0 ]; then
        exit 0
      fi

      flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

      for app in "''${wanted[@]}"; do
        if ! flatpak info --user "$app" >/dev/null 2>&1; then
          flatpak install --user -y --noninteractive flathub "$app"
        fi
      done

      flatpak update --user -y --noninteractive
    '';
  };
in
{
  options.mx.services.flatpak = {
    enable = lib.mkEnableOption "Enable flatpak service";

    apps = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "com.github.tchx84.Flatseal" ];
      description = "Flatpak application IDs to install from Flathub in the user installation.";
    };

    removedApps = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "com.discordapp.Discord" ];
      description = ''
        Flatpak application IDs to remove from the user installation. Only
        applications listed here are uninstalled, so manually installed
        flatpaks are left untouched.
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      # Pulls in flatpak itself plus the xdg portal wiring.
      services.flatpak.enable = true;

      environment.sessionVariables.XDG_DATA_DIRS = [
        "$HOME/.local/share/flatpak/exports/share"
        "/var/lib/flatpak/exports/share"
      ];

      systemd.user.services.flatpak-sync = {
        description = "Flatpak synchronization";

        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${flatpakSync}/bin/flatpak-sync";
          Restart = "on-failure";
          RestartSec = 60;
        };
      };

      # No network access during activation: the synchronization only runs from
      # the timer, shortly after the session starts.
      systemd.user.timers.flatpak-sync = {
        description = "Regular flatpak synchronization";
        wantedBy = [ "timers.target" ];

        timerConfig = {
          OnStartupSec = "2min";
          OnUnitInactiveSec = "1d";
          Unit = "flatpak-sync.service";
        };
      };
    })

    (flatpakApp "com.github.tchx84.Flatseal")
  ];
}
