{ config, lib, self, pkgs, ... }:

{
  imports = [
    ./boot.nix
    ./branding.nix
    ./options
    ./security
    ./update.nix
    ./zram.nix
    ./powersave.nix
    ./ssd.nix
    ./gpu
    ./kernel
    ./dns.nix
    ./cache.nix
    ./patch-runner.nix
    ./package-fix.nix
    ./modulix-daemon

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

  environment.systemPackages = with self.packages.${pkgs.stdenv.hostPlatform.system}; [
    mx-diff-update
    mx-clean
    mx-clean-generations
    mx-list-generations
    mx-switch-generation
    mx-redetect-hardware
  ];

  nix.settings = {
    connect-timeout = 3;
    download-attempts = 1;
    stalled-download-timeout = 10;
    fallback = true;
  };

  environment.pathsToLink = [ "/share/zsh" ];
}
