{ config, lib, pkgs, ... }:

{
  options = {
    mx.gnome.software = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "enable GNOME Software with background service";
    };
  };

  config = lib.mkIf (config.mx.desktop == "gnome" && config.mx.gnome.software) {
    environment.systemPackages = [ pkgs.gnome-software ];
    systemd.packages = [ pkgs.gnome-software ];
    systemd.user.services.gnome-software.wantedBy = [ "graphical-session.target" ];
  };
}
