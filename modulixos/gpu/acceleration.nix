{ config, lib, pkgs, ... }:

let
  gpu = config.mx.hardware.gpu;
  cfg = gpu.acceleration;

  intelLegacyGens = [ "ironlake" "sandybridge" "ivybridge" "haswell" "westmere" ];

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

  gpus =
    lib.optional (gpu.dedicated.vendor != null) { v = gpu.dedicated.vendor; g = gpu.dedicated.generation; }
    ++ lib.optional (gpu.integrated.vendor != null) { v = gpu.integrated.vendor; g = gpu.integrated.generation; };

  primary =
    if gpu.integrated.vendor != null then { v = gpu.integrated.vendor; g = gpu.integrated.generation; }
    else if gpu.dedicated.vendor != null then { v = gpu.dedicated.vendor; g = gpu.dedicated.generation; }
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
      (lib.mkIf (gpu.dedicated.vendor == "nvidia") {
        MOZ_DISABLE_RDD_SANDBOX = "1";  # Firefox VAAPI
      })
    ];
  };
}
