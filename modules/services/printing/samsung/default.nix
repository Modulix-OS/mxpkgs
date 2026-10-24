{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.mx.services.printer.samsung;
in
{
  options.mx.services.printer.samsung.enable =
    lib.mkEnableOption "Samsung printers (unified driver and the SpliX QPDL driver, also covering rebadged Dell and Xerox models)";

  config = lib.mkIf cfg.enable {
    mx.services.printer.enable = lib.mkMxDefault true;

    services.printing.drivers = with pkgs; [
      samsung-unified-linux-driver
      splix
    ];
  };
}
