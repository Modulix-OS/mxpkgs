{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.mx.services.printer.hp;
in
{
  options.mx.services.printer.hp.enable =
    lib.mkEnableOption "HP printers and all-in-ones (HPLIP CUPS driver and hpaio SANE backend)";

  config = lib.mkIf cfg.enable {
    mx.services.printer.enable = lib.mkMxDefault true;

    services.printing.drivers = [ pkgs.hplip ];

    hardware.sane.extraBackends = [ pkgs.hplip ];
  };
}
