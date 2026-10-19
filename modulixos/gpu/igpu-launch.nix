{ config, pkgs, lib, ... }:

let
  igpu = config.mx.hardware.gpu.integrated;
in
{
  options.mx.hardware.gpu.integrated.launcher = lib.mkOption {
    type = lib.types.nullOr lib.types.package;
    default =
      if igpu.pciId == null then null
      else pkgs.callPackage ../../lib/igpu-launch.nix {
        igpuId = igpu.pciId;
        igpuNumber = if igpu.drmIndex == null then 1 else igpu.drmIndex;
        pciAddr = igpu.pciAddr;
      };
    internal = true;
    readOnly = true;
    description = "Wrapper running a command on the integrated GPU, null when integrated.pciId is unset";
  };
}
