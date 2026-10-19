{ config, lib, ... }:

let
  gpu = config.mx.hardware.gpu;

  computingFor = vendor:
    if vendor == "nvidia" then "cuda"
    else if vendor == "amd" then "rocm"
    else if vendor == "intel" then "oneapi"
    else "cpu";

  computingType = lib.types.enum [ "cuda" "rocm" "oneapi" "cpu" ];

  gpuSlot = slot: role: {
    vendor = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "amd" "nvidia" "intel" ]);
      default = null;
      description = "${role} GPU vendor (amd, nvidia, intel). null = no ${lib.toLower role} GPU.";
    };

    generation = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        ${role} GPU generation codename, vendor-specific:
          nvidia: fermi, kepler, maxwell, pascal, volta, turing, ampere, ada-lovelace, blackwell
          amd:    rdna2, rdna3, rdna4 ...
          intel:  ironlake, sandybridge, ivybridge, haswell, broadwell, skylake, tigerlake, arc ...
      '';
    };

    pciId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "8086:46a6";
      description = "${role} GPU PCI vendor:device id, as reported by `lspci -nn` (used by MESA_VK_DEVICE_SELECT)";
    };

    pciAddr = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "00:02.0";
      description = "${role} GPU PCI address, as reported by `lspci` (used by DRI_PRIME)";
    };

    drmIndex = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      example = 1;
      description = "${role} GPU index among the /sys/class/drm cards (used by the MangoHud gpu_list)";
    };

    computing = lib.mkOption {
      type = computingType;
      default = computingFor gpu.${slot}.vendor;
      internal = true;
      readOnly = true;
      description = "Compute stack of the ${lib.toLower role} GPU, auto-derived from its vendor";
    };
  };

  renames = [
    { from = [ "vendor" ];            to = [ "dedicated" "vendor" ]; }
    { from = [ "generation" ];        to = [ "dedicated" "generation" ]; }
    { from = [ "igpu" "vendor" ];     to = [ "integrated" "vendor" ]; }
    { from = [ "igpu" "generation" ]; to = [ "integrated" "generation" ]; }
  ];

  gpuPath = [ "mx" "hardware" "gpu" ];
in
{
  imports = map (r: lib.mkRenamedOptionModule (gpuPath ++ r.from) (gpuPath ++ r.to)) renames;

  options.mx.hardware.gpu = {
    dedicated = gpuSlot "dedicated" "Dedicated";
    integrated = gpuSlot "integrated" "Integrated";
  };
}
