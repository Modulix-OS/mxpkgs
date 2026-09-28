{ config, pkgs, lib, ... }:

let
  cfg = config.mx.programs.games;

  presetsPath = "/etc/MangoHud/presets.conf";
  configPath = "/etc/MangoHud/MangoHud.conf";

  styleBase = ''
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

  styleBar = ''
    ${styleBase}
    horizontal
    hud_no_margin
    table_columns=1
    position=top-center
    background_alpha=0
  '';

  stylePanel = ''
    ${styleBase}
    position=top-left
    background_alpha=0.4
  '';

  elementsFps = ''
    fps
    time
  '';

  elementsBasic = ''
    gpu_stats
    cpu_stats
    vram
    ram
    battery
    fps
    frame_timing
    time
  '';

  elementsDetailed = ''
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

  elementsFull = ''
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

  presetsFile = pkgs.writeText "mangohud-presets.conf" ''
    [preset 1]
    ${styleBar}
    ${elementsFps}

    [preset 2]
    ${styleBar}
    ${elementsBasic}

    [preset 3]
    ${stylePanel}
    ${elementsDetailed}

    [preset 4]
    ${stylePanel}
    ${elementsFull}
  '';

  globalConfig = {
    control = "mangohud";
    gpu_list = "0";
    preset = [ "0" "1" "2" "3" "4" ];
    toggle_preset = "Shift_R+F10";
    toggle_hud = "Shift_R+F12";
    toggle_hud_position = "Shift_R+F11";
    toggle_fps_limit = "Shift_L+F1";
    fps_limit_method = "late";
    fps_limit = [ "0" "165" "60" "30" ];
  };

  renderValue = sep: value:
    if builtins.isList value then lib.concatStringsSep sep value else toString value;

  toEnvString = attrs: lib.concatStringsSep ","
    (lib.mapAttrsToList (key: value: "${key}=${renderValue "\\," value}") attrs);

  toConfText = attrs: lib.concatMapStrings (line: "${line}\n")
    (lib.mapAttrsToList (key: value: "${key}=${renderValue "," value}") attrs);

  configFile = pkgs.writeText "MangoHud.conf" (toConfText globalConfig);
in
{
  options.mx.programs.games.mangohud = {
    presetsFile = lib.mkOption {
      type = lib.types.str;
      internal = true;
      readOnly = true;
      default = presetsPath;
      description = "Path of the system-wide MangoHud presets file.";
    };

    configFile = lib.mkOption {
      type = lib.types.str;
      internal = true;
      readOnly = true;
      default = configPath;
      description = "Path of the system-wide MangoHud configuration file.";
    };

    sessionEnv = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      internal = true;
      readOnly = true;
      default = {
        MANGOHUD = "0";
        MANGOHUD_CONFIGFILE = configPath;
        MANGOHUD_PRESETSFILE = presetsPath;
      };
      description = ''
        Environment for sessions where mangoapp draws the overlay instead of the
        Vulkan layer. Values must stay shell-safe: the NixOS gamescope session
        wrapper exports them unquoted.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment = {
      etc."MangoHud/presets.conf".source = presetsFile;
      etc."MangoHud/MangoHud.conf".source = configFile;

      sessionVariables = {
        MANGOHUD = "1";
        MANGOHUD_PRESETSFILE = presetsPath;
        MANGOHUD_CONFIG = toEnvString globalConfig;
      };

      systemPackages = [
        pkgs.mangohud
        pkgs.goverlay
      ];
    };
  };
}
