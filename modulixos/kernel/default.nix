{ config, pkgs, lib, inputs, ... }:
let
  cfg = config.mx.kernel;
  bfqProfile = config.mx.programs.games.enable || config.mx.programs._studio.enable;
in
{
  options.mx.kernel = {
    cachyos-kernel = {
      enable = lib.mkEnableOption "Enable cachyOS Kernel";
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.cachyosKernels.linuxPackages_cachyos;
        description = "CachyOS kernel package";
      };
    };
  };

  config = {
    boot.kernelPackages = lib.mkIf cfg.cachyos-kernel.enable
  (lib.mkForce (pkgs.linuxPackagesFor cfg.cachyos-kernel.package));

    boot.extraModulePackages = lib.optional config.mx.programs._studio.enable
      config.boot.kernelPackages.v4l2loopback;

    services.udev.extraRules = lib.mkIf bfqProfile ''
      ACTION=="add|change", KERNEL=="sd[a-z]|mmcblk[0-9]*|nvme[0-9]*n[0-9]*", ATTR{queue/scheduler}="bfq"
    '';

    boot.supportedFilesystems.zfs = lib.mkMxDefault false;
    boot.zfs.package = lib.mkIf cfg.cachyos-kernel.enable
    (lib.mkMxDefault cfg.cachyos-kernel.package.zfs_cachyos);
    nix.settings.substituters = []
    ++ lib.optionals cfg.cachyos-kernel.enable [ "https://attic.xuyh0120.win/lantian" ];
    nix.settings.trusted-public-keys = []
     ++ lib.optionals cfg.cachyos-kernel.enable [ "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc=" ];
    nixpkgs.overlays = [
      inputs.nix-cachyos-kernel.overlays.pinned
    ];
  };
}
