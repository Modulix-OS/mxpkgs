{ pkgs, lib, config, ... }:

let
  cfg = config.mx.plasma;
  deEnabled = config.mx.desktop == "plasma";
  modulix-logo = pkgs.callPackage ../../../pkgs/modulix-logo.nix { };
in
{
  options.mx.plasma = {
    kde-connect = lib.mkEnableOption "Enable KDE Connect";
    core-app = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable core app application auto managed";
    };
  };

  config = lib.mkMerge [
    (
      lib.mkIf deEnabled {
        services = {
          displayManager.sddm = {
            enable = true;
            wayland.enable = true;
          };
          desktopManager.plasma6.enable = true;
        };
        environment.systemPackages = [ modulix-logo ];
        environment.plasma6.excludePackages = with pkgs.kdePackages; [
          kwin-x11 # Wayland-only session
          baloo-widgets
          elisa
          krdp
          kwalletmanager
          discover
          kate
          qrca
          khelpcenter
        ] ++ lib.optional (!cfg.core-app) [
          gwenview
          okular
          dolphin
          dolphin-plugins
          spectacle
          plasma-keyboard
          qtvirtualkeyboard
          print-manager
          kmenuedit
          plasma-systemmonitor
          kinfocenter
          ark
          konsole
          plasma-browser-integration
          plasma-workspace-wallpapers
        ];
      }
    )
    (
      lib.mkIf (deEnabled && config.mx.plasma.kde-connect) {
        programs.kdeconnect.enable = true;
        networking.firewall = rec {
          allowedTCPPortRanges = [ { from = 1714; to = 1764; } ];
          allowedUDPPortRanges = allowedTCPPortRanges;
        };
      }
    )
  ];
}
