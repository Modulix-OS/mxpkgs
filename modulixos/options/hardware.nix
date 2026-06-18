{ lib, ... }:
{
  options.mx.hardware = {
    laptop = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Is the system a laptop?";
    };

    has_fingerprint = lib.mkEnableOption "Enable fingerprint sensor";
  };
}
