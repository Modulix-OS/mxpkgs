{ pkgs, lib, config, inputs, ... }:

let
  cfg = config.mx.hardware.gpu.nvidia;
  igpu = config.mx.hardware.gpu.integrated;

  nvidia = config.mx.hardware.gpu.dedicated.vendor == "nvidia";
  isLaptop = config.mx.hardware.laptop;

  legacy-390 = config.mx.hardware.gpu.dedicated.generation ==  "fermi";
  legacy-470 = config.mx.hardware.gpu.dedicated.generation == "kepler";
  legacy-580 = builtins.elem config.mx.hardware.gpu.dedicated.generation [  "maxwell" "pascal" "volta" ];

  legacyDriver = legacy-390 || legacy-470 || legacy-580;

  primeConfigured =
    cfg.nvidiaBusId != null && (cfg.intelBusId != null || cfg.amdBusId != null);

  gamesEnabled = config.mx.programs.games.enable;

  nvidiaUnstablePackages = config.boot.kernelPackages.callPackage
    "${inputs.nixpkgs-unstable}/pkgs/os-specific/linux/nvidia-x11" { };

  nvidiaLatestDriver =
    if gamesEnabled then
      nvidiaUnstablePackages.latest
    else
      config.boot.kernelPackages.nvidiaPackages.production;

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
      example = "PCI:0:2:0";
      description = ''
        Bus id of the Intel integrated GPU, in the `PCI:bus:device:function` form
        NixOS expects: the `lspci` address with bus and device in decimal and
        without leading zeros, so `00:02.0` becomes `PCI:0:2:0`.

        Setting it together with `nvidiaBusId` is what turns NVIDIA PRIME on.
        Left null, PRIME stays off even when an imported `nixos-hardware` module
        asks for it.
      '';
    };
    nvidiaBusId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "PCI:1:0:0";
      description = ''
        Bus id of the dedicated NVIDIA GPU, in the `PCI:bus:device:function` form
        NixOS expects: the `lspci` address with bus and device in decimal and
        without leading zeros, so `01:00.0` becomes `PCI:1:0:0`.

        Only meaningful alongside `intelBusId` or `amdBusId`: PRIME pairs a
        dedicated GPU with an integrated one, so setting it alone is an error.
      '';
    };
    amdBusId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "PCI:5:0:0";
      description = ''
        Bus id of the AMD integrated GPU, in the `PCI:bus:device:function` form
        NixOS expects: the `lspci` address with bus and device in decimal and
        without leading zeros, so `05:00.0` becomes `PCI:5:0:0`.

        Setting it together with `nvidiaBusId` is what turns NVIDIA PRIME on.
        Left null, PRIME stays off even when an imported `nixos-hardware` module
        asks for it.
      '';
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
          assertion = (!cfg.disable && cfg.nvidiaBusId != null) -> (cfg.intelBusId != null || cfg.amdBusId != null);
          message = "mx.hardware.gpu.nvidia: nvidiaBusId requires intelBusId or amdBusId for PRIME";
        }
        {
          assertion = (cfg.intelBusId != null || cfg.amdBusId != null) -> cfg.nvidiaBusId != null;
          message = "mx.hardware.gpu.nvidia: intelBusId/amdBusId requires nvidiaBusId for PRIME";
        }
        {
          assertion = cfg.experimental-power-management -> primeConfigured;
          message = "mx.hardware.gpu.nvidia: experimental-power-management sets hardware.nvidia.powerManagement.finegrained, which NixOS only accepts with PRIME offload; set nvidiaBusId plus intelBusId or amdBusId (hybrid laptop), or leave it off";
        }
        {
          assertion = cfg.disable -> isLaptop;
          message = "mx.hardware.gpu.nvidia: disable option only works on a laptop (mx.hardware.laptop must be true)";
        }
        {
          assertion = cfg.intelBusId != null -> igpu.vendor == "intel";
          message = "mx.hardware.gpu.nvidia: intelBusId requires mx.hardware.gpu.integrated.vendor = \"intel\"";
        }
        {
          assertion = cfg.amdBusId != null -> igpu.vendor == "amd";
          message = "mx.hardware.gpu.nvidia: amdBusId requires mx.hardware.gpu.integrated.vendor = \"amd\"";
        }
      ];
    })
    (
      lib.mkIf (nvidia && !cfg.disable) {
        # Force LTS kernel with old nvidia GPU
        boot.kernelPackages = lib.mkIf legacyDriver (lib.mkForce pkgs.linuxPackages); # Recommended with legacy drivers
        mx.kernel.cachyos-kernel.enable = lib.mkIf legacyDriver (lib.mkForce false);

        boot.initrd.kernelModules = []
        ++ lib.optional (igpu.vendor == "intel") "i915"
        ++ lib.optional (igpu.vendor == "amd") "amdgpu";


        hardware.nvidia = {
          modesetting.enable = true;  # required for Wayland (nixpkgs default already true)
          package = lib.mkMxDefault
            (
            if legacy-390 then
              config.boot.kernelPackages.nvidiaPackages.legacy_390
            else if legacy-470 then
              config.boot.kernelPackages.nvidiaPackages.legacy_470
            else if legacy-580 then
              config.boot.kernelPackages.nvidiaPackages.legacy_580
            else
              nvidiaLatestDriver
            );
          open = lib.mkMxDefault (!legacyDriver);
          prime = lib.mkMerge [
            (lib.mkIf (cfg.intelBusId != null) { intelBusId = lib.mkMxDefault cfg.intelBusId; })
            (lib.mkIf (cfg.nvidiaBusId != null) { nvidiaBusId = lib.mkMxDefault cfg.nvidiaBusId; })
            (lib.mkIf (cfg.amdBusId != null) { amdgpuBusId = lib.mkMxDefault cfg.amdBusId; })
            (lib.mkIf (!primeConfigured) {
              offload.enable = lib.mkMxDefault false;
              offload.enableOffloadCmd = lib.mkMxDefault false;
              sync.enable = lib.mkMxDefault false;
              reverseSync.enable = lib.mkMxDefault false;
            })
          ];
          dynamicBoost.enable = isLaptop && !legacyDriver;
          powerManagement.enable = lib.mkMxDefault true;
          powerManagement.finegrained = lib.mkMxDefault (!legacyDriver && cfg.experimental-power-management && primeConfigured);
        };

        systemd.services.nvidia-suspend.enable = lib.mkMxDefault true;
        systemd.services.nvidia-resume.enable = lib.mkMxDefault true;
        systemd.services.nvidia-hibernate.enable = lib.mkMxDefault true;

        environment.variables = {
          __GL_SHADER_DISK_CACHE_SIZE = (if gamesEnabled then "12000000000" else "2000000000");
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
