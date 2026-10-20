{ config, pkgs, lib, ... }:
let
  cgpu = config.mx.hardware.gpu;
  hasStack = lib.mxGpuHasStack cgpu;
  cfg = cgpu.compute;

  oneapiLegacyGens = [
    "broadwell"
    "skylake"
    "kabylake"
    "coffeelake"
    "cometlake"
    "apollolake"
    "geminilake"
    "icelake"
    "jasperlake"
    "elkhartlake"
  ];

  intelGens = map (slot: slot.generation)
    (lib.filter (slot: slot.vendor == "intel") [ cgpu.dedicated cgpu.integrated ]);

  oneapiLegacy = lib.any (g: g != null && builtins.elem g oneapiLegacyGens) intelGens;

  rocmEnv = pkgs.symlinkJoin {
    name = "rocm-combined";
    paths = with pkgs.rocmPackages; [
      rocblas
      hipblas
      clr
    ];
  };
in
{
  options.mx.hardware.gpu.compute = {
    enable = lib.mkEnableOption "GPU compute (OpenCL / CUDA / oneAPI runtimes)";

    rusticl.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Mesa rusticl OpenCL ICD alongside the ROCm one. Off by default: both
        ICDs enumerate the same physical GPUs, so OpenCL consumers such as
        DaVinci Resolve list every board twice. Turn it on for AMD GPUs the
        ROCm runtime does not enumerate.
      '';
    };

    rocmStack.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Full ROCm/HIP stack: the /opt/rocm tree and nixpkgs.config.rocmSupport.
        Needed only by HIP applications (Blender, llama.cpp) and triggers large
        rebuilds. OpenCL-only consumers such as DaVinci Resolve leave it off.
      '';
    };

    nvidiaOffloadEnv.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Set __NV_PRIME_RENDER_OFFLOAD and __GLX_VENDOR_LIBRARY_NAME system-wide so
        compute applications reach the discrete NVIDIA GPU on a hybrid laptop.
        Off by default because it routes every GL client to the discrete GPU.
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable (lib.mkMerge [
      { hardware.graphics.enable = true; }

      (lib.mkIf (hasStack "rocm") {
        hardware.amdgpu.opencl.enable = true;
      })

      (lib.mkIf (hasStack "rocm" && cfg.rusticl.enable) {
        hardware.graphics.extraPackages = with pkgs; [
          mesa.opencl
        ];
        environment.variables = {
          RUSTICL_ENABLE = "radeonsi";
        };
      })

      (lib.mkIf (hasStack "oneapi") {
        hardware.graphics = {
          enable32Bit = true;
          extraPackages = [
            (if oneapiLegacy then pkgs.intel-compute-runtime-legacy1 else pkgs.intel-compute-runtime)
          ];
        };
      })
    ]))

    (lib.mkIf (cfg.enable && cfg.rocmStack.enable && hasStack "rocm") {
      systemd.tmpfiles.rules = [
        "L+    /opt/rocm   -    -    -     -    ${rocmEnv}"
      ];
      environment.variables = {
        ROC_ENABLE_PRE_VEGA = "1";
      };
      nixpkgs.config.rocmSupport = true;
    })

    (lib.mkIf (cfg.nvidiaOffloadEnv.enable && hasStack "cuda") {
      environment.variables = {
        __NV_PRIME_RENDER_OFFLOAD = "1";
        __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      };
    })
  ];
}
