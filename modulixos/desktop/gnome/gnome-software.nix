{ config, lib, pkgs, inputs, ... }:

let
  gnome-software-modulix = inputs.gnome-software-plugin.packages.${pkgs.system}.default;
in
{
  options = {
    mx.gnome.software = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "enable GNOME Software with background service";
    };
  };

  config = lib.mkIf (config.mx.desktop == "gnome" && config.mx.gnome.software) {
    environment.systemPackages = [ gnome-software-modulix ];
    systemd.packages = [ gnome-software-modulix ];
    systemd.user.services.gnome-software.wantedBy = [ "graphical-session.target" ];
  };
}
