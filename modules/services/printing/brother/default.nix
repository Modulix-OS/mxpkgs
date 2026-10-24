{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.mx.services.printer.brother;
in
{
  options.mx.services.printer.brother.enable =
    lib.mkEnableOption "Brother printers (brlaser and the BrGenML1 CUPS wrapper, printing only)";

  config = lib.mkIf cfg.enable {
    mx.services.printer.enable = lib.mkMxDefault true;

    services.printing.drivers = with pkgs; [
      brgenml1cupswrapper
      brgenml1lpr
      brlaser
    ];
  };
}
