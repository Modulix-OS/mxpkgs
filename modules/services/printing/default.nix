{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.mx.services.printer;
  normalUser = import ../../../lib/normal-user.nix { inherit config; };
  scanFrontend =
    if config.mx.desktop == "plasma" then
      [ pkgs.kdePackages.skanpage ]
    else
      lib.optional (config.mx.desktop != "cli") pkgs.simple-scan;
in
{
  options.mx.services.printer = {
    enable = lib.mkEnableOption "Enable printer services";

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = normalUser;
      description = "List of normal users who can access printer services";
    };
  };

  config = lib.mkIf cfg.enable {
    services = {
      printing = {
        enable = true;
        startWhenNeeded = lib.mkMxDefault true;
        browsed.enable = lib.mkMxDefault false;
        drivers = with pkgs; [
          # Brother BrGenML1 CUPS wrapper driver
          brgenml1cupswrapper

          # Brother BrGenML1 LPR driver
          brgenml1lpr

          # Brother laser printers
          brlaser

          # Canon Pixma series
          cnijfilter2

          # Ghostscript and cups printer drivers
          gutenprint

          # HP
          hplip

          # Epson
          epson-escpr2
          epson-escpr

          # Samsung
          samsung-unified-linux-driver
          splix
        ];
      };

      ipp-usb.enable = lib.mkMxDefault true;

      avahi = {
        enable = true;
        nssmdns4 = lib.mkMxDefault true;
        nssmdns6 = lib.mkMxDefault true;
        openFirewall = lib.mkMxDefault true;
      };
    };

    hardware.sane = {
      enable = true;
      extraBackends = with pkgs; [
        sane-airscan
        epkowa
        utsushi
        hplip
      ];
    };

    programs.system-config-printer.enable = true;

    environment.systemPackages = scanFrontend;

    users.groups.scanner.members = cfg.users;
    users.groups.lp.members = cfg.users;
  };
}
