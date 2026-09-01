{ config, lib, ... }:

{
  imports = [
    ./boot.nix
    ./options
    ./security
    ./update.nix
    ./zram.nix
    ./powersave.nix
    ./ssd.nix
    ./gpu
    ./kernel
    ./dns.nix
    ./patch-runner.nix

    # Desktop only
    ./sound.nix
    ./network.nix
    ./ios-connect.nix
    ./bluetooth.nix
    ./nix-ld.nix
    ./filesystem.nix
    ./fingerprint.nix

    # Desktop environments, user config, base fonts
    ./desktop
    ./home-manager
    ./fonts
  ];
  nixpkgs.config.allowUnfree = lib.mkMxDefault true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  system.stateVersion = lib.mkMxDefault config.system.nixos.release;



  documentation.nixos.enable = false;

  hardware.fw-fanctrl.enable = config.mx.hardware.framework-fan-ctrl.enable;
  hardware.enableRedistributableFirmware = lib.mkMxDefault true;
  hardware.enableAllFirmware = lib.mkMxDefault true;
}
