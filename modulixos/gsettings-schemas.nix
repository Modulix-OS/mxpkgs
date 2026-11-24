{ pkgs, ... }:

{
  environment.sessionVariables.XDG_DATA_DIRS = [
    "${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}"
    "${pkgs.gtk4}/share/gsettings-schemas/${pkgs.gtk4.name}"
    "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}"
  ];
}
