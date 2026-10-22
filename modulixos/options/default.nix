{ lib, ... }:
{
  imports = [
    ./hardware.nix
    ./hardware-cpu.nix
    ./hardware-gpu.nix
    ./framework.nix
  ];

  # General internal options
  options.mx = {
    programs._studio.enable = lib.mkEnableOption "Enable Studio optimization";
    mode.server.enable = lib.mkEnableOption "Enable server option";

    languages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "fr" ];
      example = [ "fr" "en-US" ];
      description = ''
        Interface locales, most preferred first. Locales that ship a known
        hunspell dictionary (see lib/mx-dictionaries.nix) are also enabled for
        spell checking and hyphenation; the others only get what the
        application provides on its own and are reported as a warning.
      '';
    };
  };
}
