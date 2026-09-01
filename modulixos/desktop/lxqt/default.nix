{ pkgs, lib, config, ... }:

let
  deEnabled = config.mx.desktop == "lxqt";
in
{
  config = lib.mkIf deEnabled {
    services.xserver = {
      # displayManager.lightdm.enable = true;
      desktopManager.lxqt.enable = true;
      windowManager.openbox.enable = false;
    };

    # Automatic mounting device (moved out of modulixos/filesystem.nix)
    services.devmon.enable = true;

    environment.lxqt.excludePackages = with pkgs.lxqt; [
        ### CORE 1
        libfm-qt
        lxqt-about
        lxqt-admin
        lxqt-config
        lxqt-globalkeys
        lxqt-menu-data
        lxqt-notificationd
        lxqt-openssh-askpass
        lxqt-policykit
        lxqt-powermanagement
        lxqt-qtplugin
        lxqt-session
        lxqt-sudo
        lxqt-themes
        lxqt-wayland-session
        pavucontrol-qt

        ### CORE 2
        lxqt-panel
        lxqt-runner
        pcmanfm-qt

        ### LXQt project
        qterminal
        obconf-qt
        lximage-qt
        lxqt-archiver

        ### QtDesktop project
        qps
        screengrab

        ### Default icon theme
        pkgs.kdePackages.breeze-icons

        ### Screen saver
        pkgs.xscreensaver
    ];

    environment.systemPackages = with pkgs.lxqt; [
        lxqt-wayland-session
    ];

    environment.sessionVariables = {
        LXQT_WINDOW_MANAGER = "xfwm4";
    };
  };
}
