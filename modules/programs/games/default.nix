{ config, pkgs, pkgs-unstable, lib, ... }:

let
  cfg = config.mx.programs.games;
  cgpu = config.mx.hardware.gpu;

  proton-cachyos = pkgs.callPackage ../../../pkgs/proton-cachyos.nix { };
  protonCompatTools = pkgs.linkFarm "mx-proton-compat-tools" [
    { name = "proton-cachyos"; path = proton-cachyos.steamcompattool; }
    { name = "proton-ge"; path = pkgs-unstable.proton-ge-bin.steamcompattool; }
  ];

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

  mangohudStyleBase = ''
    legacy_layout=0
    round_corners=0
    background_color=000000
    font_size=24
    text_color=FFFFFF
    gpu_text=GPU
    cpu_text=CPU
    gpu_color=2E9762
    cpu_color=2E97CB
    vram_color=AD64C1
    ram_color=C26693
    battery_color=00FF00
    engine_color=EB5B5B
    wine_color=EB5B5B
    frametime_color=00FF00
  '';

  mangohudStyleBar = ''
    ${mangohudStyleBase}
    horizontal
    hud_no_margin
    table_columns=1
    position=top-center
    background_alpha=0
  '';

  mangohudStylePanel = ''
    ${mangohudStyleBase}
    position=top-left
    background_alpha=0.4
  '';

  mangohudElementsFps = ''
    fps
    time
  '';

  mangohudElementsBasic = ''
    gpu_stats
    cpu_stats
    vram
    ram
    battery
    fps
    frame_timing
    time
  '';

  mangohudElementsDetailed = ''
    gpu_stats
    gpu_temp
    gpu_core_clock
    gpu_mem_clock
    gpu_power
    cpu_stats
    cpu_temp
    cpu_mhz
    cpu_power
    vram
    ram
    battery
    fps
    frametime
    frame_timing
    time
  '';

  mangohudElementsFull = ''
    gpu_name
    gpu_stats
    gpu_temp
    gpu_junction_temp
    gpu_mem_temp
    gpu_core_clock
    gpu_mem_clock
    gpu_power
    gpu_fan
    gpu_voltage
    cpu_stats
    cpu_temp
    cpu_mhz
    cpu_power
    core_load
    core_bars
    core_type
    vram
    ram
    swap
    procmem
    io_read
    io_write
    battery
    fps
    frametime
    fps_metrics=avg,0.01
    frame_timing
    throttling_status
    resolution
    refresh_rate
    vulkan_driver
    engine_version
    arch
    wine
    time
  '';

  mangohudPresets = pkgs.writeText "mangohud-presets.conf" ''
    [preset 1]
    ${mangohudStyleBar}
    ${mangohudElementsFps}

    [preset 2]
    ${mangohudStyleBar}
    ${mangohudElementsBasic}

    [preset 3]
    ${mangohudStylePanel}
    ${mangohudElementsDetailed}

    [preset 4]
    ${mangohudStylePanel}
    ${mangohudElementsFull}
  '';


in
{

  imports = [
    ./steam
    ./lutris
    ./heroic
    ./umu
  ];

  options.mx.programs.games = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.steam.enable || cfg.lutris.enable || cfg.heroic.enable || cfg.umu.enable;
      description = "Whether shared gaming config is active (auto: any launcher enabled).";
    };

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
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
        package = pkgs.gamescope;

        capSysNice = true;
      };
      gamemode = {
        enable = true;
        settings = {
          general.renice = 10;
          gpu = {
            amd_performance_level = lib.mkIf (cgpu.vendor == "amd") "high";
            nv_powermizer_mode = lib.mkIf (cgpu.vendor == "nvidia") 1;
          };
        };
      };
    };

    environment = {
      sessionVariables = {
        STEAM_EXTRA_COMPAT_TOOLS_PATHS = "${protonCompatTools}:\${HOME}/.steam/root/compatibilitytools.d";

        MANGOHUD_PRESETSFILE = "/etc/MangoHud/presets.conf";
        MANGOHUD_CONFIG = lib.concatStringsSep "," [
          "control=mangohud"
          "gpu_list=0"
          "preset=0\\,1\\,2\\,3\\,4"
          "toggle_preset=Shift_R+F10"
          "toggle_hud=Shift_R+F12"
          "toggle_hud_position=Shift_R+F11"
          "toggle_fps_limit=Shift_L+F1"
          "fps_limit_method=late"
          "fps_limit=0\\,165\\,60\\,30"
        ];

        MESA_SHADER_CACHE_MAX_SIZE= lib.mkIf (cgpu.vendor == "amd") "12G";
        __GL_SHADER_DISK_CACHE_SIZE= lib.mkIf (cgpu.vendor == "nvidia") "12000000000";

      };

      etc."MangoHud/presets.conf".source = mangohudPresets;
    };
    environment.systemPackages = [
      pkgs.mangohud
      pkgs-unstable.vkbasalt
      pkgs-unstable.goverlay
      mx-game
    ];
    hardware = {
        graphics = {
          enable = true;
          enable32Bit = true;
          package = if cfg.latest-unstable-mesa-driver.enable then pkgs-unstable.mesa else pkgs.mesa;
          package32 = if cfg.latest-unstable-mesa-driver.enable then pkgs-unstable.pkgsi686Linux.mesa else pkgs.pkgsi686Linux.mesa;
        };
    };

    users.groups = {
      gamers.members = cfg.users;
    };

    users.users = lib.mkMerge (map (user: {
      ${user}.extraGroups = [ "gamemode" ];
    }) cfg.users);

    systemd.tmpfiles.rules = map (p: "d ${p} 0770 root gamers -") cfg.game_lib_dirs;

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
      tmp.cleanOnBoot = true;
      kernel.sysctl = {
        "kernel.split_lock_mitigate" = 0;
        "vm.vfs_cache_pressure" = 50;
        "vm.dirty_bytes" = 268435456;
        "vm.max_map_count" = 16777216;
        "vm.dirty_background_bytes" = 67108864;
        "vm.dirty_writeback_centisecs" = 1500;
        "kernel.nmi_watchdog" = 0;
        "kernel.unprivileged_userns_clone" = 1;
        "kernel.printk" = "3 3 3 3";
        "kernel.kptr_restrict" = 2;
        "kernel.kexec_load_disabled" = 1;
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
