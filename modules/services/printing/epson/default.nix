{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.mx.services.printer.epson;
in
{
  options.mx.services.printer.epson.enable =
    lib.mkEnableOption "Epson printers and scanners (ESC/P-R CUPS filters, epkowa and utsushi SANE backends)";

  config = lib.mkIf cfg.enable {
    mx.services.printer.enable = lib.mkMxDefault true;

    services.printing.drivers = with pkgs; [
      epson-escpr
      epson-escpr2
    ];

    hardware.sane.extraBackends = with pkgs; [
      epkowa
      utsushi
    ];
  };
}
