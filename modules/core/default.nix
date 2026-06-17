{ config, lib, pkgs, ... }:

let
  cgpu = config.mx.hardware.gpu;
in
{
  imports = [
    ./boot.nix
    ./fix.nix
    ./options
    ./security.nix
    ./sound.nix
    ./update.nix
    ./zram.nix
    ./powersave.nix
    ./bluetooth.nix
    ./ios-connect.nix
    ./ssd.nix
    ./network.nix
    ./gpu-computing.nix
    ./nvidia.nix
    ./gpu-acceleration.nix
    ./patch-runner.nix
    ./kernel
  ];
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  system.stateVersion = config.system.nixos.release;
  services.xserver.videoDrivers = [
   (if cgpu.vendor == "amd" then "amdgpu"
     else if cgpu.vendor == "intel" || cgpu.vendor == "nvidia" then cgpu.vendor else "auto") ];

  programs.nix-ld = {
      enable = lib.mkDefault true;
      libraries = with pkgs; [
        stdenv.cc.cc.lib # libstdc++
        zlib # libz
        glib # libglib
      ];
    };

  documentation.nixos.enable = false;

  hardware.fw-fanctrl.enable = config.mx.hardware.framework-fan-ctrl.enable;
  hardware.enableRedistributableFirmware = true;
  hardware.enableAllFirmware = true;
}
