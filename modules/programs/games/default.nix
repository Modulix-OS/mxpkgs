{ config, pkgs, pkgs-unstable, lib, ... }:

let
  cfg = config.mx.programs.games;
  cgpu = config.mx.hardware.gpu;

  proton-cachyos = pkgs.callPackage ../../../pkgs/proton-cachyos.nix { arch=pkgs.stdenv.hostPlatform.system; };
  proton-ge = pkgs.callPackage ../../../pkgs/proton-ge.nix { arch=pkgs.stdenv.hostPlatform.system; };

  protonTools = [ proton-cachyos proton-ge ];

  protonCompatTools = pkgs.linkFarm "mx-proton-compat-tools" (
    map (p: { name = p.dirName; path = p.steamcompattool; }) protonTools
  );

  normalUsers = import ../../../lib/normal-user.nix { inherit config; };

  gameServices = import ../../../lib/mx-game-services.nix { inherit lib config; };

  mx-game = import ../../../pkgs/mx-game.nix {
    inherit lib pkgs;
    services = gameServices.enabledUnits;
    fwFanCtrl = config.mx.hardware.framework-fan-ctrl.enable;
    desktop = config.mx.desktop;
    enableHDR = cfg.enableHDR;
    obsCapture = config.mx.programs.studio.obs-studio.enable;
  };

in
{

  imports = [
    ./steam
    ./lutris
    ./heroic
    ./umu
    ./bindfs-shared-mount.nix
    ./game_folder.nix
    ./folder_check.nix
    ./mangohud.nix
  ];

  options.mx.programs.games = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.steam.enable || cfg.lutris.enable || cfg.heroic.enable || cfg.umu.enable;
      description = "Whether shared gaming config is active (auto: any launcher enabled).";
    };

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = normalUsers;
      description = "Users added to the 'gamers' group.";
    };

    game_lib_dirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Folder with games shared for all gamers user";
    };

    latest-unstable-mesa-driver.enable = lib.mkEnableOption "Enable latest unstable Mesa driver";

    enableHDR = lib.mkEnableOption "Enable HDR on games";
  };

  config = lib.mkIf cfg.enable {
    programs = {
      gamescope = {
        enable = true;
        package = lib.mkMxDefault pkgs.gamescope;

        capSysNice = lib.mkMxDefault (!cfg.gamescopeSession.enable);
      };
      gamemode = {
        enable = true;
        settings = {
          general.renice = lib.mkMxDefault 10;
          gpu = {
            amd_performance_level = lib.mkIf (cgpu.vendor == "amd") (lib.mkMxDefault "high");
            nv_powermizer_mode = lib.mkIf (cgpu.vendor == "nvidia") (lib.mkMxDefault 1);
          };
        };
      };
    };

    environment = {
      sessionVariables = {
        STEAM_EXTRA_COMPAT_TOOLS_PATHS = "${protonCompatTools}:\${HOME}/.steam/root/compatibilitytools.d";

        MESA_SHADER_CACHE_MAX_SIZE= lib.mkIf (cgpu.vendor == "amd") "12G";
        __GL_SHADER_DISK_CACHE_SIZE= lib.mkIf (cgpu.vendor == "nvidia") "12000000000";

      };
    };
    environment.systemPackages = [
      pkgs-unstable.vkbasalt
      mx-game
    ] ++ protonTools;

    systemd.user.tmpfiles.rules = [
      "d %h/.local/share/Steam/compatibilitytools.d 0755 - - -"
    ] ++ map (p:
      "L+ %h/.local/share/Steam/compatibilitytools.d/${p.dirName} - - - - ${p.steamcompattool}"
    ) protonTools;
    hardware = {
        graphics = {
          enable = true;
          enable32Bit = lib.mkMxDefault true;
          package = lib.mkMxDefault (if cfg.latest-unstable-mesa-driver.enable then pkgs-unstable.mesa else pkgs.mesa);
          package32 = lib.mkMxDefault (if cfg.latest-unstable-mesa-driver.enable then pkgs-unstable.pkgsi686Linux.mesa else pkgs.pkgsi686Linux.mesa);
        };
    };

    users.groups = {
      gamers.members = cfg.users;
    };

    users.users = lib.mkMerge (map (user: {
      ${user}.extraGroups = [ "gamemode" ];
    }) cfg.users);

    services.udev.extraRules = ''
      ACTION=="add|change", SUBSYSTEM=="block", ATTR{queue/scheduler}="bfq"
    '';

    # Enable VK basalt compatibility
    system.activationScripts.vkbasalt-compat = ''
      mkdir -p /usr/share/vulkan/implicit_layer.d
      ln -sf /run/current-system/sw/share/vulkan/implicit_layer.d/vkBasalt.json /usr/share/vulkan/implicit_layer.d/vkBasalt.json

      mkdir -p /usr/lib
      if [ -f "${pkgs-unstable.vkbasalt}/lib/libvkbasalt.so" ]; then
        ln -sf "${pkgs-unstable.vkbasalt}/lib/libvkbasalt.so" /usr/lib/libvkbasalt.so
      fi
    '';

    boot = {
      kernelPackages = pkgs.linuxPackages_zen;
      tmp.cleanOnBoot = lib.mkMxDefault true;
      kernel.sysctl = {
        "kernel.split_lock_mitigate" = lib.mkMxDefault 0;
        "vm.vfs_cache_pressure" = lib.mkMxDefault 50;
        "vm.dirty_bytes" = lib.mkMxDefault 268435456;
        "vm.max_map_count" = lib.mkMxDefault 16777216;
        "vm.dirty_background_bytes" = lib.mkMxDefault 67108864;
        "vm.dirty_writeback_centisecs" = lib.mkMxDefault 1500;
        "kernel.nmi_watchdog" = lib.mkMxDefault 0;
        "kernel.unprivileged_userns_clone" = lib.mkMxDefault 1;
        "kernel.printk" = lib.mkMxDefault "3 3 3 3";
        "kernel.kptr_restrict" = lib.mkMxDefault 2;
        "kernel.kexec_load_disabled" = lib.mkMxDefault 1;
      };
    };

    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        var allowedUnits = ${builtins.toJSON gameServices.enabledUnits};

        if (action.id === "org.freedesktop.systemd1.manage-units" &&
            subject.isInGroup("wheel") &&
            allowedUnits.indexOf(action.lookup("unit")) !== -1) {
          return polkit.Result.YES;
        }

        if (action.id === "org.freedesktop.UPower.PowerProfiles.switch-profile" &&
            subject.isInGroup("wheel")) {
          return polkit.Result.YES;
        }
      });
    '';
  };
}
