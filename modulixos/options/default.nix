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
  };
}
