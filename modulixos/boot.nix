{ pkgs, lib, config, ... }:

let
  cfg = config.mx.bootloader;
  splashBackground = ../assets/bootloader-background.png;
  logo = ../assets/modulix-logo.png;
  plymouthTheme = pkgs.callPackage ../pkgs/modulix-plymouth-theme.nix {
    logo = cfg.splash.logo;
    watermarkVerticalAlignment = cfg.splash.logoPosition;
  };
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
    extraEntries = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              example = "Windows Boot Manager";
              description = ''
                Label shown for this entry in the Limine menu. It must contain
                neither a newline nor a slash: Limine reads `/` as the entry
                separator and `//` as a sub-entry marker.
              '';
            };
            efiPath = lib.mkOption {
              type = lib.types.str;
              example = "/EFI/Microsoft/Boot/bootmgfw.efi";
              description = ''
                Absolute path of the EFI executable to chainload, relative to
                the root of the EFI system partition holding it.
              '';
            };
            esp = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              example = "49eaf743-20fe-44fa-b9fe-b0944153ac72";
              description = ''
                GPT partition GUID (`PARTUUID`) of the EFI system partition
                holding `efiPath`, for an operating system installed on another
                EFI partition. `null` means `efiPath` lives on the partition
                Limine itself booted from.

                The filesystem UUID of a FAT partition (`D950-99F7`) does not
                work here: Limine's `guid()` resolver parses 128-bit GUIDs.
              '';
            };
          };
        }
      );
      default = [ ];
      example = [
        {
          name = "Windows Boot Manager";
          efiPath = "/EFI/Microsoft/Boot/bootmgfw.efi";
          esp = "49eaf743-20fe-44fa-b9fe-b0944153ac72";
        }
      ];
      description = ''
        Boot entries for the other operating systems installed on the machine,
        chainloaded by Limine. Written by `mx-init` from what it detected on
        the EFI system partitions, and replaced wholesale on every redetection.

        A non-empty list also raises the menu timeout from 1 to 5 seconds and
        drops Limine's `quiet` mode: a menu nobody can reach is of no use on a
        dual-boot machine, and `quiet` keeps Limine from ever initialising its
        terminal, so the menu stays hidden behind the firmware logo until a key
        is pressed.
      '';
    };
    splash = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Show the Modulix branding across the boot: Limine background image,
          then the Plymouth screen, which drops the firmware vendor logo and
          draws the Modulix logo large on a black background, with the spinner
          below it.
        '';
      };
      image = lib.mkOption {
        type = lib.types.path;
        default = splashBackground;
        description = "Bootloader background image (PNG).";
      };
      logo = lib.mkOption {
        type = lib.types.path;
        default = logo;
        defaultText = lib.literalExpression "../assets/modulix-logo.png";
        description = ''
          Modulix logo drawn on the Plymouth screen (PNG). The theme scales it
          down to 960 pixels wide, so it stays within screens narrower than the
          source image.
        '';
      };
      logoPosition = lib.mkOption {
        type = lib.types.float;
        default = 0.5;
        description = ''
          Vertical position of the Modulix logo on the Plymouth screen, from
          0.0 (top) to 1.0 (bottom). Plymouth places the image at
          `logoPosition * (screenHeight - logoHeight)`, so the value is
          resolution independent. 0.5 centres it; the upstream `spinner` theme
          uses 0.96 for its watermark.
        '';
      };
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

          extraConfig = lib.concatStringsSep "\n" (
            lib.optional (cfg.extraEntries == [ ]) "quiet: yes"
            ++ [ "remember_last_entry: no" ]
          );
          extraEntries = lib.concatMapStrings (e: ''
            /${e.name}
                protocol: efi_chainload
                image_path: ${
                  if e.esp == null then "boot()" else "guid(${e.esp})"
                }:${e.efiPath}
          '') cfg.extraEntries;
          style = lib.mkIf cfg.splash.enable {
            wallpapers = [ cfg.splash.image ];
            wallpaperStyle = lib.mkMxDefault "stretched";
            interface = {
              branding = lib.mkMxDefault "ModulixOS";
              helpHidden = lib.mkMxDefault true;
            };
          };
        };

        boot.loader.timeout = lib.mkMxDefault (if cfg.extraEntries == [ ] then 1 else 5);
        boot.loader.efi.canTouchEfiVariables = lib.mkMxDefault false;
      }
    )
    {
      boot = {
        kernelPackages = lib.mkDefault pkgs.linuxPackages;
        tmp.useTmpfs = lib.mkMxDefault true;

        kernelParams = [
          "quiet"
          "udev.log_level=3"
          "rd.udev.log_level=3"
          "systemd.show_status=false"
          "rd.systemd.show_status=false"
          "vt.global_cursor_default=0"
          "iommu=pt" # Fix pour certain cpu AMD
        ];
        consoleLogLevel = lib.mkMxDefault 3;

        plymouth = {
          enable = lib.mkMxDefault (!config.mx.mode.server.enable);
          logo = lib.mkIf cfg.splash.enable (lib.mkMxDefault cfg.splash.logo);
          theme = lib.mkIf cfg.splash.enable (lib.mkMxDefault "modulix");
          themePackages = lib.mkIf cfg.splash.enable [ plymouthTheme ];
        };
      };

      # Fastest boot
      systemd.network.wait-online.enable = false;
      systemd.services.systemd-udev-settle.enable = lib.mkForce false;
    }
  ];
}
