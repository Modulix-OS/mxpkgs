{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.mx.services.printer.canon;
in
{
  options.mx.services.printer.canon.enable =
    lib.mkEnableOption "Canon printers (cnijfilter2 for the Pixma series, printing only)";

  config = lib.mkIf cfg.enable {
    mx.services.printer.enable = lib.mkMxDefault true;

    services.printing.drivers = [ pkgs.cnijfilter2 ];
  };
}
