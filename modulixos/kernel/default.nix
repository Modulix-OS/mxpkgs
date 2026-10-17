{ config, pkgs, lib, inputs, ... }:
let
  cachyosSupport = false;
  cfg = config.mx.kernel;
  bfqProfile = config.mx.programs.games.enable || config.mx.programs._studio.enable;
  cachyosEnabled = cachyosSupport && cfg.cachyos-kernel.enable;
in
{
  options.mx.kernel = {
    cachyos-kernel = {
      enable = lib.mkEnableOption "Enable cachyOS Kernel";
      package = lib.mkOption {
        type = lib.types.package;
        default = if cachyosSupport then pkgs.cachyosKernels.linuxPackages_cachyos else pkgs.linuxPackages;
        defaultText = lib.literalExpression "pkgs.cachyosKernels.linuxPackages_cachyos";
        description = "CachyOS kernel package";
      };
    };
  };

  config = {
    boot.kernelPackages = lib.mkIf cachyosEnabled
      (lib.mkForce (pkgs.linuxPackagesFor cfg.cachyos-kernel.package));

    boot.extraModulePackages = lib.optional config.mx.programs._studio.enable
      config.boot.kernelPackages.v4l2loopback;

    services.udev.extraRules = lib.mkIf bfqProfile ''
      ACTION=="add|change", KERNEL=="sd[a-z]|mmcblk[0-9]*|nvme[0-9]*n[0-9]*", ATTR{queue/scheduler}="bfq"
    '';

    boot.supportedFilesystems.zfs = lib.mkMxDefault false;
    boot.zfs.package = lib.mkIf cachyosEnabled
      (lib.mkMxDefault cfg.cachyos-kernel.package.zfs_cachyos);

    nixpkgs.overlays = lib.optionals cachyosSupport [
      inputs.nix-cachyos-kernel.overlays.pinned
    ];

    nix.settings.substituters = lib.optionals cachyosEnabled [
      "https://attic.xuyh0120.win/lantian"
      # "https://cache.xinux.uz"
    ];

    nix.settings.trusted-public-keys = lib.optionals cachyosEnabled [
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
      # "cache.xinux.uz:BXCrtqejFjWzWEB9YuGB7X2MV4ttBur1N8BkwQRdH+0="
    ];
  };
}
