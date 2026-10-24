{ pkgs, config, lib, ... }:

let
  cfg = config.mx.programs.creativity.blender;
  cgpu = config.mx.hardware.gpu;
  hasCuda = lib.mxGpuHasStack cgpu "cuda";
  hasRocm = lib.mxGpuHasStack cgpu "rocm";

  blenderPkg =
    if hasRocm then
      pkgs.pkgsRocm.blender.override { cudaSupport = hasCuda; }
    else if hasCuda then
      pkgs.blender.override {
        cudaSupport = true;
        rocmSupport = false;
      }
    else
      pkgs.blender;

  blenderWrapped = pkgs.callPackage ../../../../lib/blender-gpu-wrapper.nix {
    blender = blenderPkg;
    rocmLLVM = pkgs.rocmPackages.llvm.llvm.lib;
    gpuBackend = "vulkan";
  };
in
{
  options.mx.programs.creativity.blender = {
    enable = lib.mkEnableOption "Enable Blender (GPU-accelerated)";
  };

  config = lib.mkIf cfg.enable {
    mx.hardware.gpu.compute.enable = true;
    mx.hardware.gpu.compute.rocmStack.enable = lib.mkIf hasRocm true;
    mx.fonts.enable = true;
    environment.systemPackages = [
      (if hasRocm then blenderWrapped else blenderPkg)
    ];
  };
}
