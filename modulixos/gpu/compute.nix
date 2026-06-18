{ config, pkgs, lib, ... }:
let
  cgpu = config.mx.hardware.gpu;
  cfg = cgpu.compute;

  defaultBackend =
    if cgpu.vendor == "amd" then "rocm"
    else if cgpu.vendor == "nvidia" then "cuda"
    else if cgpu.vendor == "intel" then "intel"
    else "cpu";
in
{
  options.mx.hardware.gpu.compute = {
    enable = lib.mkEnableOption "GPU compute (ROCm / CUDA / oneAPI / OpenCL)";

    backend = lib.mkOption {
      type = lib.types.enum [ "cuda" "rocm" "intel" "cpu" ];
      default = defaultBackend;
      description = "Compute backend used by GPU-accelerated apps (auto-derived from vendor)";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    # Compute runtimes need the graphics stack, even headless.
    { hardware.graphics.enable = true; }

    (lib.mkIf (cgpu.vendor == "amd") {
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
    })

    (lib.mkIf (cgpu.vendor == "intel") {
      hardware.graphics.extraPackages = with pkgs; [
        intel-compute-runtime
      ];
    })

    # nvidia: CUDA is handled per-application via package overrides (cudaSupport);
    # no system-level packages needed beyond the graphics stack enabled above.
  ]);
}
