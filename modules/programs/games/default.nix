{ config, pkgs, pkgs-unstable, lib, ... }:

let
  cfg = config.mx.programs.games;
  cgpu = config.mx.hardware.gpu;
  conf_service = config.mx.services;

  proton-cachyos = pkgs.callPackage ../../../pkgs/proton-cachyos.nix { };
  protonCompatTools = pkgs.linkFarm "mx-proton-compat-tools" [
    { name = "proton-cachyos"; path = proton-cachyos.steamcompattool; }
    { name = "proton-ge"; path = pkgs-unstable.proton-ge-bin.steamcompattool; }
  ];

  normalUsers = import ../../../lib/normal-user.nix { inherit config; };

  mx-game = import ../../../pkgs/mx-game.nix {
    lib = lib;
    pkgs = pkgs;
    dockerEnable = conf_service.docker.enable;
    llmEnable = conf_service.llm.enable;
    open-webuiEnable = conf_service.llm.open-webui.enable;
    lampEnable = conf_service.lamp.enable;
    printingEnable = conf_service.printer.enable;
    teamviewerEnable = config.mx.programs.team-viewer.enable;
    vmEnable = conf_service.vm.enable;
    fwFanCtrl = config.mx.hardware.framework-fan-ctrl.enable;
  };

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

    gamemode.users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = normalUsers;
      description = "Users for gamemode permissions should be enabled.";
    };

    latest-unstable-mesa-driver.enable = lib.mkEnableOption "Enable latest unstable Mesa driver";

    enableHDR = lib.mkEnableOption "Enable HDR on games";
  };

  config = lib.mkIf cfg.enable {
    programs = {
      gamescope = {
        enable = true;
        package = pkgs.gamescope;

        # HOT FIX: TODO CHANGE WHEN WORK'S
        capSysNice = false;
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

    users.groups.gamemode.members = cfg.gamemode.users;

    environment = {
      sessionVariables = {
        STEAM_EXTRA_COMPAT_TOOLS_PATHS = "${protonCompatTools}:\${HOME}/.steam/root/compatibilitytools.d";

        MANGOHUD_CONFIG = "control=mangohud,gpu_list=0,hud_no_margin,legacy_layout=false,horizontal,round_corners=0,background_alpha=0,background_color=000000,font_size=24,text_color=FFFFFF,position=top-center,toggle_hud=Shift_R+F12,no_display,table_columns=1,gpu_text=GPU,gpu_stats,gpu_temp,gpu_power,gpu_color=2E9762,cpu_text=CPU,cpu_stats,cpu_temp,cpu_power,cpu_color=2E97CB,vram,vram_color=AD64C1,ram,ram_color=C26693,battery,battery_color=00FF00,fps,gpu_name,wine,wine_color=EB5B5B,fps_limit_method=late,toggle_fps_limit=Shift_R+F1,fps_limit=0\\,165\\,60\\,30,time";

        MESA_SHADER_CACHE_MAX_SIZE= lib.mkIf (cgpu.vendor == "amd") "12G";
        __GL_SHADER_DISK_CACHE_SIZE= lib.mkIf (cgpu.vendor == "nvidia") "12000000000";

      };
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
        var allowedUnits = [
          "docker.service", "docker.socket",
          "ollama.service",
          "llama-cpp.service",
          "open-webui.service",
          "httpd.service", "mysql.service",
          "postgresql.service",
          "cups.service", "cups.socket",
          "teamviewerd.service",
          "libvirtd.service", "libvirtd.socket",
          "virtlogd.service", "virtlogd.socket"
        ];

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
