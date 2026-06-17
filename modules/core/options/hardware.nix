{ lib, ... }:
{
  options.mx.hardware = {
    laptop = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Is the system a laptop?";
    };

    gpu = {
      vendor = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "GPU constructor (amd, nvidia, intel)";
      };

      enable-computing = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "enable gpu computing (cuda, rocm)";
      };

      computing = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "computing (cuda, rocm, intel, cpu)";
      };

      generation = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "GPU génération (blackwell, ada-lovelace, ampere for NVidia; rdna4, rdna3, rdna2 for AMD)";
      };
    };
  };
}
