{ pkgs, config, lib, ... }:

let
  cfg = config.mx.services.sim-hardware;
  normalUsers = import ../../../lib/normal-user.nix { inherit config; };
  fanatecff = config.boot.kernelPackages.hid-fanatecff;
  thrustmasterff = config.boot.kernelPackages.hid-tmff2;
in
{
  options.mx.services.sim-hardware = {
    enable = lib.mkEnableOption "Enable simulation hardware support (racing wheels, pedals, joysticks)";

    logitech = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Logitech wheel support through the out-of-tree new-lg4ff driver, which
        replaces the in-kernel hid-logitech modules and adds the force-feedback
        effects they lack.
      '';
    };

    fanatec = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Fanatec wheel base, pedal and shifter support through the out-of-tree hid-fanatec driver.";
    };

    thrustmaster = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Thrustmaster wheel support through the out-of-tree hid-tmff2 driver.";
    };

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = normalUsers;
      description = "Users added to the 'games' group, which the wheel drivers' udev rules grant sysfs access to.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      environment.systemPackages = [
        pkgs.oversteer
        pkgs.linuxConsoleTools
      ];

      services.udev.packages = [ pkgs.oversteer ];

      users.groups.games.members = cfg.users;
    }

    (lib.mkIf cfg.logitech {
      hardware.new-lg4ff.enable = true;

      services.udev.extraRules = ''
        ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="c261", RUN+="${pkgs.usb-modeswitch}/bin/usb_modeswitch -v 046d -p c261 -m 01 -r 01 -C 03 -M '0f00010142'"
      '';
    })

    (lib.mkIf cfg.fanatec {
      boot.extraModulePackages = [ fanatecff ];
      boot.kernelModules = [ "hid-fanatec" ];
      services.udev.packages = [ fanatecff ];
    })

    (lib.mkIf cfg.thrustmaster {
      boot.extraModulePackages = [ thrustmasterff ];
      services.udev.packages = [ thrustmasterff ];
    })
  ]);
}
