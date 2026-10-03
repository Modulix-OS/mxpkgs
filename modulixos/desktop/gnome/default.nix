{ pkgs, lib, config, ... }:

let
  deEnabled = config.mx.desktop == "gnome";
  cfg = config.mx.gnome;
in
{
    options.mx.gnome = {
      gsconnect = lib.mkEnableOption "Enable GSConnect";
      remote-desktop = lib.mkEnableOption "Enable GNOME remote desktop";
    };

    imports = [
      ./numlock.nix
      ./trash.nix
      ./gnome-software.nix
      ./custom.nix
    ];

    config = lib.mkMerge [
      (
        lib.mkIf deEnabled {
          services = {
            displayManager.gdm.enable = true;
            displayManager.defaultSession = lib.mkMxDefault "gnome";
            desktopManager.gnome.enable = true;
          };

          environment.gnome.excludePackages = with pkgs; [
              atomix # puzzle game
              cheese # webcam tool
              baobab
              snapshot
              simple-scan
              eog
              file-roller
              seahorse
              epiphany # web browser
              papers # document viewer
              geary # email reader
              gnome-characters
              gnome-music
              gnome-photos
              gnome-tour
              hitori # sudoku game
              iagno # go game
              tali # poker game
              totem # video player
              yelp
              gnome-calculator
              gnome-calendar
              gnome-clocks
              gnome-contacts
              gnome-font-viewer
              gnome-logs
              gnome-maps
              gnome-screenshot
              gnome-system-monitor
              gnome-weather
              gnome-connections
              gnome-software
              gnome-disk-utility
              gnome-console
              gnome-text-editor
              nautilus
              decibels
              loupe
              cups
              simple-scan
              gnome-shell-extensions
              showtime
              decibels
          ];
      }
    )
    (
      lib.mkIf (deEnabled && cfg.gsconnect) {
        networking.firewall = rec {
          allowedTCPPortRanges = [ { from = 1714; to = 1764; } ];
          allowedUDPPortRanges = allowedTCPPortRanges;
        };
      }
    )
    (
      lib.mkIf (deEnabled && cfg.remote-desktop) {
        services.gnome.gnome-remote-desktop.enable = true;
        systemd.services.gnome-remote-desktop = {
          wantedBy = [ "graphical.target" ];
        };
        networking.firewall.allowedTCPPorts = [ 3389 ];
        networking.firewall.allowedUDPPorts = [ 3389 ];
      }
    )
  ];
}
