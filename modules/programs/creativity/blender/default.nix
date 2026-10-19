{ pkgs, config, lib, ... }:

let
  cfg = config.mx.programs.creativity.blender;
  cgpu = config.mx.hardware.gpu;
  hasCuda = lib.mxGpuHasStack cgpu "cuda";
  hasRocm = lib.mxGpuHasStack cgpu "rocm";
in
{
  options.mx.programs.creativity.blender = {
    enable = lib.mkEnableOption "Enable Blender (GPU-accelerated)";
  };

  config = lib.mkIf cfg.enable {
    mx.hardware.gpu.compute.enable = true;
    mx.fonts.enable = true;
    environment.systemPackages = [
      (if hasRocm then
          pkgs.pkgsRocm.blender.override { cudaSupport = hasCuda; }
        else if hasCuda then
          pkgs.blender.override {
            cudaSupport = true;
            rocmSupport = false;
          }
        else
          pkgs.blender)
    ];
  };
}
