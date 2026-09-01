{ pkgs, lib, config, ... }:

let
  cfg = config.mx.bootloader;
in
{
  options.mx.bootloader = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use default bootloader";
    };
    secureBoot.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable secure boot";
    };
  };
  config = lib.mkMerge [
    (
      lib.mkIf cfg.enable {
        boot.loader.limine = {
          enable = true;
          maxGenerations = lib.mkMxDefault 10;
          secureBoot = {
            enable = cfg.secureBoot.enable;
            autoGenerateKeys = lib.mkMxDefault cfg.secureBoot.enable;
            autoEnrollKeys = {
              enable = cfg.secureBoot.enable;
              extraArgs = [
                "--microsoft"
                "--firmware-builtin"
              ];
            };
          };
          extraConfig = ''
            timeout: 1
            quiet: yes
            remember_last_entry: no
          '';
        };

        boot.loader.efi.canTouchEfiVariables = lib.mkMxDefault true;
      }
    )
    {
      boot = {
        kernelPackages = lib.mkDefault pkgs.linuxPackages;
        initrd.verbose = lib.mkMxDefault false;
        tmp.useTmpfs = lib.mkMxDefault true;
        kernelParams = lib.mkDefault [
          "quiet"
          "udev.log_level=3"
          "iommu=pt" # Fix pour certain cpu AMD
        ];

        initrd.systemd.enable = lib.mkDefault true;
        plymouth.enable = lib.mkMxDefault (!config.mx.mode.server.enable);

        initrd.systemd.tpm2.enable = true;
        initrd.systemd.services.systemd-udev-settle.enable = lib.mkForce false;
      };

      # Fastest boot
      systemd.network.wait-online.enable = false;
      systemd.services.systemd-udev-settle.enable = lib.mkForce false;
    }
  ];
}
