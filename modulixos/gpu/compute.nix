{ config, pkgs, lib, ... }:
let
  cgpu = config.mx.hardware.gpu;
  hasStack = lib.mxGpuHasStack cgpu;
  cfg = cgpu.compute;
in
{
  options.mx.hardware.gpu.compute = {
    enable = lib.mkEnableOption "GPU compute (ROCm / CUDA / oneAPI / OpenCL)";
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    # Compute runtimes need the graphics stack, even headless.
    { hardware.graphics.enable = true; }

    (lib.mkIf (hasStack "rocm") {
      systemd.tmpfiles.rules =
        let
          rocmEnv = pkgs.symlinkJoin {
            name = "rocm-combined";
            paths = with pkgs.rocmPackages; [
              rocblas
              hipblas
              clr
            ];
          };
        in [
          "L+    /opt/rocm   -    -    -     -    ${rocmEnv}"
        ];
      hardware.amdgpu.opencl.enable = true;
      hardware.graphics.extraPackages = with pkgs; [
        mesa.opencl
      ];
      environment.variables = {
        ROC_ENABLE_PRE_VEGA = "1";
        RUSTICL_ENABLE      = "radeonsi";
      };
      nixpkgs.config.rocmSupport = true;
    })

    (lib.mkIf (hasStack "oneapi") {
      hardware.graphics.extraPackages = with pkgs; [
        intel-compute-runtime
      ];
    })

    # nvidia: CUDA is handled per-application via package overrides (cudaSupport);
    # no system-level packages needed beyond the graphics stack enabled above.
  ]);
}
