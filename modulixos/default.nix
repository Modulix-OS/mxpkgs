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
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  system.stateVersion = config.system.nixos.release;



  documentation.nixos.enable = false;

  hardware.fw-fanctrl.enable = config.mx.hardware.framework-fan-ctrl.enable;
  hardware.enableRedistributableFirmware = true;
  hardware.enableAllFirmware = true;
}
