{ pkgs, lib, config, ... }:

let
  cfg = config.mx.hardware.gpu.nvidia;

  nvidia = config.mx.hardware.gpu.vendor == "nvidia";
  isLaptop = config.mx.hardware.laptop;

  legacy-390 = config.mx.hardware.gpu.generation ==  "fermi";
  legacy-470 = config.mx.hardware.gpu.generation == "kepler";
  legacy-580 = builtins.elem config.mx.hardware.gpu.generation [  "maxwell" "pascal" "volta" ];

  legacyDriver = legacy-390 || legacy-470 || legacy-580;

  nvidia580Driver = config.boot.kernelPackages.nvidiaPackages.mkDriver {
    version = "580.142";
    sha256_64bit = "sha256-IJFfzz/+icNVDPk7YKBKKFRTFQ2S4kaOGRGkNiBEdWM=";
    sha256_aarch64 = "sha256-jntr88SpTYR648P1rizQjB/8KleBoa14Ay12vx8XETM=";
    openSha256 = "sha256-v968LbRqy8jB9+yHy9ceP2TDdgyqfDQ6P41NsCoM2AY=";
    settingsSha256 = "sha256-BnrIlj5AvXTfqg/qcBt2OS9bTDDZd3uhf5jqOtTMTQM=";
    persistencedSha256 = "sha256-il403KPFAnDbB+dITnBGljhpsUPjZwmLjGt8iPKuBqw=";
  };

  nvidia595Driver = config.boot.kernelPackages.nvidiaPackages.mkDriver {
    version = "595.58.03";
    sha256_64bit = "sha256-jA1Plnt5MsSrVxQnKu6BAzkrCnAskq+lVRdtNiBYKfk=";
    sha256_aarch64 = "sha256-hzzIKY1Te8QkCBWR+H5k1FB/HK1UgGhai6cl3wEaPT8=";
    openSha256 = "sha256-6LvJyT0cMXGS290Dh8hd9rc+nYZqBzDIlItOFk8S4n8=";
    settingsSha256 = "sha256-2vLF5Evl2D6tRQJo0uUyY3tpWqjvJQ0/Rpxan3NOD3c=";
    persistencedSha256 = "sha256-AtjM/ml/ngZil8DMYNH+P111ohuk9mWw5t4z7CHjPWw=";
  };

in
{

  options.mx.hardware.gpu.nvidia = {
    disable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Disable nvidia card work only for laptop";
    };
    intelBusId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    nvidiaBusId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    amdBusId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    experimental-power-management = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable experimental power management for NVIDIA GPUs";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf nvidia {
      assertions = [
        {
          assertion = !(cfg.intelBusId != null && cfg.amdBusId != null);
          message = "mx.hardware.gpu.nvidia: intelBusId and amdBusId cannot both be set";
        }
        {
          assertion = (isLaptop && !cfg.disable && cfg.nvidiaBusId != null) -> (cfg.intelBusId != null || cfg.amdBusId != null);
          message = "mx.hardware.gpu.nvidia: nvidiaBusId requires intelBusId or amdBusId for PRIME";
        }
        {
          assertion = cfg.disable -> isLaptop;
          message = "mx.hardware.gpu.nvidia: disable option only works on a laptop (mx.hardware.laptop must be true)";
        }
      ];
    })
    (
      lib.mkIf (nvidia && !cfg.disable) {
        # Force LTS kernel with old nvidia GPU
        boot.kernelPackages = lib.mkIf legacyDriver (lib.mkForce pkgs.linuxPackages); # Recommended with legacy drivers
        mx.programs.games.cachyos-kernel.enable = lib.mkIf legacyDriver (lib.mkForce false);

        boot.initrd.kernelModules = []
        ++ lib.optional (cfg.intelBusId != null) "i915"
        ++ lib.optional (cfg.amdBusId != null) "amdgpu";


        hardware.nvidia = {
          package =
            (
            if legacy-390 then
              config.boot.kernelPackages.nvidiaPackages.legacy_390
            else if legacy-470 then
              config.boot.kernelPackages.nvidiaPackages.legacy_470
            else if legacy-580 then
              nvidia580Driver
            else
              nvidia595Driver
            );
          open = !legacyDriver;
          prime = {
            intelBusId = lib.optionalString (cfg.intelBusId != null) cfg.intelBusId;
            nvidiaBusId = lib.optionalString (cfg.nvidiaBusId != null) cfg.nvidiaBusId;
            amdgpuBusId = lib.optionalString (cfg.amdBusId != null) cfg.amdBusId;
          };
          dynamicBoost.enable = isLaptop && !legacyDriver;
          powerManagement.enable = lib.mkDefault true;
          powerManagement.finegrained = !legacyDriver && cfg.experimental-power-management;
        };

        systemd.services.nvidia-suspend.enable = lib.mkDefault true;
        systemd.services.nvidia-resume.enable = lib.mkDefault true;
        systemd.services.nvidia-hibernate.enable = lib.mkDefault true;

        environment.variables = {
          __GL_SHADER_DISK_CACHE_SIZE = (if config.mx.programs.games.enable then "12000000000" else "2000000000");
        };


        boot.blacklistedKernelModules = ["nouveau" "nova_core"];
      }
    )
    (
      lib.mkIf (isLaptop && nvidia && cfg.disable) {
        boot.extraModprobeConfig = ''
           blacklist nouveau
           options nouveau modeset=0
         '';

         services.udev.extraRules = ''
           # Remove NVIDIA USB xHCI Host Controller devices, if present
           ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c0330", ATTR{power/control}="auto", ATTR{remove}="1"

           # Remove NVIDIA USB Type-C UCSI devices, if present
           ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c8000", ATTR{power/control}="auto", ATTR{remove}="1"

           # Remove NVIDIA Audio devices, if present
           ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", ATTR{power/control}="auto", ATTR{remove}="1"

           # Remove NVIDIA VGA/3D controller devices
           ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x03[0-9]*", ATTR{power/control}="auto", ATTR{remove}="1"
         '';
         boot.blacklistedKernelModules = [
           "nouveau"
           "nvidia"
           "nvidia_drm"
           "nvidia_modeset"
         ];
      }
    )
  ];
}
