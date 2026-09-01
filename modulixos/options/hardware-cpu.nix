{ lib, config, ... }:
let
  cfg = config.mx.hardware.cpu;
in
{
  options.mx.hardware.cpu = {
    vendor = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "intel" "amd" ]);
      default = null;
      description = ''
        CPU vendor (intel, amd). Drives the microcode update package.

        The integrated GPU is described by `mx.hardware.gpu.igpu.*`, not here:
        video acceleration reads that option (see modulixos/gpu/acceleration.nix).
      '';
    };
  };

  config = {
    hardware.cpu.intel.updateMicrocode = lib.mkMxDefault (cfg.vendor == "intel");
    hardware.cpu.amd.updateMicrocode = lib.mkMxDefault (cfg.vendor == "amd");
  };
}
