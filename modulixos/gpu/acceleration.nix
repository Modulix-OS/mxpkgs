{ config, lib, pkgs, ... }:

let
  gpu = config.mx.hardware.gpu;
  cfg = gpu.acceleration;

  # Intel generations served by the legacy i965 (intel-vaapi-driver) stack.
  # Broadwell and newer (and unknown/null) use the modern iHD (intel-media-driver).
  intelLegacyGens = [ "ironlake" "sandybridge" "ivybridge" "haswell" "westmere" ];

  # Per-GPU video-acceleration descriptor: { packages; libvaDriver; }.
  accelFor = vendor: generation:
    if vendor == "intel" then
      (if generation != null && builtins.elem generation intelLegacyGens then {
        packages = with pkgs; [ intel-vaapi-driver libvdpau-va-gl ];
        libvaDriver = "i965";
      } else {
        packages = with pkgs; [ intel-media-driver vpl-gpu-rt libvdpau-va-gl ];
        libvaDriver = "iHD";
      })
    else if vendor == "nvidia" then {
      packages = with pkgs; [ nvidia-vaapi-driver libva-vdpau-driver libvdpau-va-gl ];
      libvaDriver = "nvidia";
    }
    else if vendor == "amd" then {
      packages = [ ];          # VAAPI/VDPAU provided by mesa (radeonsi)
      libvaDriver = "radeonsi";
    }
    else { packages = [ ]; libvaDriver = null; };

  # Every GPU present: discrete + optional integrated (hybrid laptop).
  gpus =
    lib.optional (gpu.vendor != null) { v = gpu.vendor; g = gpu.generation; }
    ++ lib.optional (gpu.igpu.vendor != null) { v = gpu.igpu.vendor; g = gpu.igpu.generation; };

  # The iGPU drives display / video decode in PRIME offload; otherwise the main GPU.
  primary =
    if gpu.igpu.vendor != null then { v = gpu.igpu.vendor; g = gpu.igpu.generation; }
    else if gpu.vendor != null then { v = gpu.vendor; g = gpu.generation; }
    else null;
in
{
  options.mx.hardware.gpu.acceleration.enable = lib.mkOption {
    type = lib.types.bool;
    default = !config.mx.mode.server.enable;
    description = "Hardware video acceleration (VAAPI / VDPAU)";
  };

  config = lib.mkIf cfg.enable {
    hardware.graphics = {
      enable = true;
      extraPackages = lib.unique (lib.concatMap (x: (accelFor x.v x.g).packages) gpus);
    };

    environment.sessionVariables = lib.mkMerge [
      (lib.mkIf (primary != null && (accelFor primary.v primary.g).libvaDriver != null) {
        LIBVA_DRIVER_NAME = (accelFor primary.v primary.g).libvaDriver;
      })
      (lib.mkIf (gpu.vendor == "nvidia") {
        MOZ_DISABLE_RDD_SANDBOX = "1";  # Firefox VAAPI
      })
    ];
  };
}
