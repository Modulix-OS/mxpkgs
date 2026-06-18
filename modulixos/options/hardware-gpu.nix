{ lib, ... }:
with lib;
{
  options.mx.hardware.gpu = {
    vendor = mkOption {
      type = types.nullOr (types.enum [ "amd" "nvidia" "intel" ]);
      default = null;
      description = "Discrete / main GPU vendor (amd, nvidia, intel)";
    };

    generation = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Main GPU generation codename, vendor-specific:
          nvidia: fermi, kepler, maxwell, pascal, volta, turing, ampere, ada-lovelace, blackwell
          amd:    rdna2, rdna3, rdna4 ...
          intel:  ironlake, sandybridge, ivybridge, haswell, broadwell, skylake, tigerlake, arc ...
      '';
    };

    # Integrated GPU on hybrid laptops. null vendor = no secondary GPU.
    igpu = {
      vendor = mkOption {
        type = types.nullOr (types.enum [ "amd" "intel" ]);
        default = null;
        description = "Integrated GPU vendor on a hybrid laptop (amd, intel)";
      };

      generation = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Integrated GPU generation codename (see gpu.generation)";
      };
    };
  };
}
