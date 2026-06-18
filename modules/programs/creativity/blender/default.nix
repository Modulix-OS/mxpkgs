{ pkgs, config, lib, ... }:

let
  cfg = config.mx.programs.creativity.blender;
  cgpu = config.mx.hardware.gpu;
in
{
  options.mx.programs.creativity.blender = {
    enable = lib.mkEnableOption "Enable Blender (GPU-accelerated)";
  };

  config = lib.mkIf cfg.enable {
    mx.hardware.gpu.compute.enable = true;
    mx.fonts.enable = true;
    environment.systemPackages = with pkgs; [
      (if cgpu.vendor == "nvidia" then
          blender.override {
            cudaSupport = true;
          }
        else if cgpu.vendor == "amd" then
          blender-hip
        else
          blender)
    ];
  };
}
