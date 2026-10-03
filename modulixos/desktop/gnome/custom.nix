{ pkgs, config, lib, self, ... }:
let
  cfg = config.mx.gnome;

  modulix-os-icon = self.packages.${pkgs.stdenv.hostPlatform.system}.modulix-icon;
  hanabi = self.packages.${pkgs.stdenv.hostPlatform.system}.gnomeExtensions.hanabi;

  deEnabled = config.mx.desktop == "gnome";
  gnome-rounded-blur = pkgs.callPackage ../../../pkgs/gnome-rounded-blur.nix { };
  logoPng = "${config.mx.branding.logo}/share/icons/hicolor/128x128/apps/modulix-logo.png";
  gdmLogoSettings = lib.optionalAttrs config.mx.branding.enable {
    "org/gnome/login-screen" = {
      logo = logoPng;
      fallback-logo = logoPng;
    };
  };

  # WALLPAPERS

  light_wallpaper_lumiere = ../../../assets/wallpapers/light-lumiere.jpg;
  dark_wallpaper_lumiere = ../../../assets/wallpapers/dark-lumiere.jpg;

  lumiereWallpaper = pkgs.writeTextDir "share/gnome-background-properties/modulixos-lumiere.xml" ''
    <?xml version="1.0"?>
    <!DOCTYPE wallpapers SYSTEM "gnome-wp-list.dtd">
    <wallpapers>
      <wallpaper deleted="false">
        <name>Mon fond</name>
        <filename>${light_wallpaper_lumiere}</filename>
        <filename-dark>${dark_wallpaper_lumiere}</filename-dark>
        <options>zoom</options>
        <shade_type>solid</shade_type>
        <pcolor>#3071AE</pcolor>
        <scolor>#000000</scolor>
      </wallpaper>
    </wallpapers>
  '';

  nixos-background-info = pkgs.emptyDirectory.overrideAttrs (_: {
    name = "nixos-background-info";
  });
in
{
  options.mx.gnome = {
    scaling = lib.mkOption {
      type = lib.types.int;
      default = 1;
      description = "GNOME scaling for GDM";
    };
    text-scaling = lib.mkOption {
      type = lib.types.float;
      default = 1.0;
      description = "GNOME text scaling for GDM";
    };
    rounded-blur = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "gnome-rounded-blur";
    };
  };

  config = lib.mkIf deEnabled {
    services.desktopManager.gnome.sessionPath = lib.optional cfg.rounded-blur gnome-rounded-blur;

    programs.dconf = {
      enable = true;
      profiles = {
        gdm.databases = [{
          settings = gdmLogoSettings // {
              "org/gnome/settings-daemon/plugins/color" = {
                  night-light-enabled = true;
              };
              "org/gnome/desktop/interface" = {
                  scaling-factor = lib.gvariant.mkUint32 cfg.scaling;
                  show-battery-percentage = true;
                  text-scaling-factor = lib.gvariant.mkDouble cfg.text-scaling;
              };
              "org/gnome/desktop/input-sources" = {
                  sources = [
                      (lib.gvariant.mkTuple["xkb" "fr+oss"])
                  ];
              };
          };
        }];
        user.databases = [{
          settings = {
            "org/gnome/desktop/background" = {
              picture-uri = "file://${light_wallpaper_lumiere}";
              picture-uri-dark = "file://${dark_wallpaper_lumiere}";
              picture-options = "zoom";
            };
            "org/gnome/settings-daemon/plugins/color" = {
                night-light-enabled = true;
            };
            "org/gnome/shell" = {
              disable-user-extensions = false;
              enabled-extensions = with pkgs.gnomeExtensions; [
                blur-my-shell.extensionUuid
                dash-to-dock.extensionUuid
                appindicator.extensionUuid
                removable-drive-menu.extensionUuid
                caffeine.extensionUuid
                places-status-indicator.extensionUuid
                quick-settings-audio-panel.extensionUuid
                upower-battery.extensionUuid
                desktop-icons-ng-ding.extensionUuid
                # display-configuration-switcher.extensionUuid
                # tiling-shell.extensionUuid
              ]
              ++ lib.optional cfg.gsconnect pkgs.gnomeExtensions.gsconnect.extensionUuid;
            };
            "org/gnome/desktop/interface" = {
              icon-theme = "Modulix-OS";
              show-battery-percentage = true;
              toolbar-style = "text";
              gtk-theme = "Adwaita";
              enable-hot-corners = false;
            };
            "org/gnome/desktop/wm/preferences" = {
              button-layout = "appmenu:minimize,maximize,close";
            };
            "org/desktop/vm/preferences" = {
              button-layout = "appmenu:minimize,maximize,close";
            };
            "org/gnome/desktop/peripherals/touchpad" = {
              click-method = "areas";
              disable-while-typing = true;
            };
            "org/gnome/shell/extensions/blur-my-shell/panel".blur = false;
            "org/gnome/shell/extensions/blur-my-shell/dash-to-dock" = {
              blur = true;
              brightness = 1.0;
              corner-radius = lib.gvariant.mkInt32 24;
              override-background = true;
              pipeline = "pipeline_default_rounded";
              sigma = lib.gvariant.mkInt32 5;
              static-blur = false;
              style-dash-to-dock = lib.gvariant.mkInt32 2;
              unblur-in-overview = false;
            };
            "org/gnome/shell/extensions/dash-to-dock" = {
              apply-custom-theme = true;
              blur = false;
             	autohide = true;
              background-opacity = 0.8;
              custom-theme-shrink = false;
              dash-max-icon-size = lib.gvariant.mkInt32 64;
              dock-fixed = false;
              dock-position = "BOTTOM";
              extend-height = false;
              height-fraction = 0.9;
              intellihide = true;
              intellihide-mode = "FOCUS_APPLICATION_WINDOWS";
              multi-monitor = true;
              preferred-monitor = lib.gvariant.mkInt32 (-2);
              scroll-to-focused-applications = true;
              show-icons-emblems = true;
              show-icons-network = false;
              show-mounts = true;
              show-mounts-neetwork = false;
              show-mounts-only-mounted = true;
              show-running = true;
              show-show-apps-button = true;
              show-trash = true;
              transparency-mode = "DEFAULT";
            };
            "org/gnome/shell/extensions/quick-settings-audio-panel" = {
              create-mpris-controllers = false;
              mpris-controllers-are-moved = false;
              panel-type = "merged-panel";
              merged-panel-position = "top";
            };
            "org/gnome/TextEditor" = {
              indent-style = "space";
              restore-session = false;
              show-line-numbers = true;
              show-right-margin = false;
              style-scheme = "Adwaita";
              tab-width = lib.gvariant.mkUint32 2;
              use-system-font = true;
            };
            "org/gnome/nautilus/list-view".use-tree-view = true;
            "org/gnome/gnome-session".logout-prompt = false;
            "org/gnome/desktop/wm/keybindings" = {
              switch-applications = ["<Super>Tab"];
              switch-applications-backward = ["<Shift><Super>Tab"];
              switch-windows = ["<Alt>Tab"];
              switch-windows-backward = ["<Shift><Alt>Tab"];
            };
            "org/gnome/baobab/preferences" = {
              excluded-uris = [
                "file:///nix/store"
              ];
            };
            "io/github/jeffshee/hanabi-extension" = {
              content-fit = lib.gvariant.mkInt32 2;
              enable-graphics-offload = true;
              enable-va = true;
              force-mediafile = true;
              pause-on-battery = lib.gvariant.mkInt32 2;
              pause-on-maximize-or-fullscreen = lib.gvariant.mkInt32 2;
              show-panel-menu = false;
              mute = true;
              volume = lib.gvariant.mkInt32 0;
              startup-delay = lib.gvariant.mkInt32 0;
            };
          };
        }];
      };
    };
    environment.gnome.excludePackages = [ nixos-background-info ];

    environment.systemPackages = with pkgs; [
      gnomeExtensions.dash-to-dock
      gnomeExtensions.blur-my-shell
      gnomeExtensions.appindicator
      gnomeExtensions.removable-drive-menu
      gnomeExtensions.caffeine
      gnomeExtensions.places-status-indicator
      gnomeExtensions.quick-settings-audio-panel
      gnomeExtensions.upower-battery
      gnomeExtensions.display-configuration-switcher
      gnomeExtensions.desktop-icons-ng-ding
      hanabi

      modulix-os-icon

      lumiereWallpaper
    ];
  };
}
