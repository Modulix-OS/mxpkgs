{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.mx.services.printing;
  normalUser = import ../../lib/normal-user.nix { inherit config; };
in
{
  options.mx.services.printing = {
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
        startWhenNeeded = true;
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

          # Some additional CUPS drivers including Canon drivers
          gutenprint-bin

          # HP
          hplip

          # Epson
          epson-escpr2
          epson-escpr
          epkowa # Scanner

          # Samsung
          samsung-unified-linux-driver
          splix
        ];
      };

      avahi = {
        enable = true;
        nssmdns4 = true;
        openFirewall = true;
      };

      udev.packages = with pkgs; [
        sane-airscan
        utsushi
      ];
    };

    hardware.sane = {
      enable = true;
      extraBackends = with pkgs; [
        sane-airscan
        epkowa
        utsushi
      ];
    };

    programs.system-config-printer.enable = true;

    users.users = builtins.listToAttrs (map (user: {
      name = user;
      value.extraGroups = [ "scanner" "lp" ];
    }) cfg.users);
  };
}
