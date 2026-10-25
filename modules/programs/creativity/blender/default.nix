{ pkgs, config, lib, ... }:

let
  cfg = config.mx.programs.creativity.blender;
  cgpu = config.mx.hardware.gpu;
  hasCuda = lib.mxGpuHasStack cgpu "cuda";
  hasRocm = lib.mxGpuHasStack cgpu "rocm";

  flatpakApp = import ../../../../lib/flatpak-app.nix { inherit lib pkgs config; };

  useFlatpak = hasCuda;

  blenderPkg =
      pkgs.blender.override { rocmSupport = hasRocm; cudaSupport = hasCuda; };

  blenderWrapped = pkgs.callPackage ../../../../lib/blender-gpu-wrapper.nix {
    blender = blenderPkg;
    rocmLLVM = pkgs.rocmPackages.llvm.llvm.lib;
    gpuBackend = "vulkan";
  };
in
{
  options.mx.programs.creativity.blender = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = ''
        Blender with GPU rendering.

        On NVIDIA the Flathub build (org.blender.Blender) is installed instead
        of the nixpkgs one. A CUDA/OptiX-enabled Blender is a multi-hour local
        compile that no binary cache covers, and the Flatpak ships the OptiX
        and HIP kernels prebuilt. AMD-only and GPU-less systems keep the
        nixpkgs build, wrapped by lib/blender-gpu-wrapper.nix on ROCm.
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      mx.hardware.gpu.compute.enable = true;
      mx.fonts.enable = true;
    })

    (lib.mkIf (cfg.enable && !useFlatpak) {
      mx.hardware.gpu.compute.rocmStack.enable = lib.mkIf hasRocm true;
      environment.systemPackages = [
        (if hasRocm then blenderWrapped else blenderPkg)
      ];
    })

    (flatpakApp.mkFlatpakConfig {
      name = "blender";
      appId = "org.blender.Blender";
      enable = cfg.enable && useFlatpak;
    })
  ];
}
