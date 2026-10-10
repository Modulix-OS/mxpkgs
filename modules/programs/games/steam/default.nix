{ config, pkgs, lib, ... }:

let
  cfg = config.mx.programs.games;
  cgpu = config.mx.hardware.gpu;
  lsfg-vk = pkgs.callPackage ../../../../pkgs/lsfg-vk.nix { };
  lsfg-vk-ui = pkgs.callPackage ../../../../pkgs/lsfg-vk-ui.nix { };

  mkFhsDesktop = pkg: desktopFile: bin:
    pkg.overrideAttrs (old: {
      postInstall = (old.postInstall or "") + ''
        sed -i 's|Exec=${bin}|Exec=${pkgs.steam}/bin/steam-run ${pkg}/bin/${bin}|g' \
          $out/share/applications/${desktopFile}
      '';
    });

  lsfg-vk-ui-fhs = mkFhsDesktop lsfg-vk-ui "gay.pancake.lsfg-vk-ui.desktop" "lsfg-vk-ui";
in
{
  options.mx.programs.games = {
    steam.enable = lib.mkEnableOption "Install Steam";

    force-fsr4-for-rdna3 = lib.mkEnableOption "Force FSR4 on AMD 7000 series";

    lsfg = {
      enable = lib.mkEnableOption "Install Losseless Scaling (required Lossless scaling app on Steam) but not enable by default";
      activate_on_all_games = lib.mkEnableOption "Activate Lossless Scaling on all games by default";

      steam_library_for_lossless_scaling = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to lossless scaling DLL";
      };
    };

    gamescopeSession = {
      enable = lib.mkEnableOption "Enable gamescope dedicated session";
      screen = {
        width = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          description = "Forced scanout width, null keeps the panel native mode";
          default = null;
        };
        height = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          description = "Forced scanout height, null keeps the panel native mode";
          default = null;
        };
        output = lib.mkOption {
          type = lib.types.nullOr (lib.types.listOf lib.types.str);
          description = "Preferred DRM connectors in order of preference, null lets gamescope pick the output";
          default = null;
          example = [ "DP-1" "HDMI-A-1" ];
        };
      };
    };
  };

  config = lib.mkIf cfg.steam.enable {
    programs.steam = {
      enable = true;
      gamescopeSession = {
        enable = cfg.gamescopeSession.enable;
        args = [
          "--backend"
          "drm"
          "--adaptive-sync"
          "--rt"
          "--force-grab-cursor"
          "--mangoapp"
        ]
        ++ lib.optionals (cfg.gamescopeSession.screen.width != null) [
          "-W"
          (toString cfg.gamescopeSession.screen.width)
        ]
        ++ lib.optionals (cfg.gamescopeSession.screen.height != null) [
          "-H"
          (toString cfg.gamescopeSession.screen.height)
        ]
        ++ lib.optionals (cfg.gamescopeSession.screen.output != null
                          && cfg.gamescopeSession.screen.output != [ ]) [
          "-O"
          (lib.concatStringsSep "," cfg.gamescopeSession.screen.output)
        ]
        ++ lib.optional cfg.enableHDR "--hdr-enabled";
        env = {
          TZ = lib.mkMxDefault ":/etc/localtime";
          ENABLE_GAMESCOPE_WSI = lib.mkMxDefault "1";
          MX_GAMESCOPE_SESSION = "1";
          XKB_DEFAULT_LAYOUT   = lib.mkMxDefault config.services.xserver.xkb.layout;
        }
        // cfg.mangohud.sessionEnv
        // lib.optionalAttrs cfg.enableHDR {
          DXVK_HDR = lib.mkMxDefault "1";
        }
        // lib.optionalAttrs (config.services.xserver.xkb.variant != "") {
          XKB_DEFAULT_VARIANT = lib.mkMxDefault config.services.xserver.xkb.variant;
        };
      };
      remotePlay.openFirewall = lib.mkMxDefault false;
      dedicatedServer.openFirewall = lib.mkMxDefault false;
      localNetworkGameTransfers.openFirewall = lib.mkMxDefault true;
      extraPackages = [ ]
      ++ lib.optionals cfg.lsfg.enable [
        lsfg-vk
        lsfg-vk-ui-fhs
      ];
      package = lib.mkMxDefault (pkgs.steam.override {
        extraEnv = {
          TZ = ":/etc/localtime";
          OBS_VKCAPTURE = config.mx.programs.studio.obs-studio.enable;
          # PROTON_NO_D3D12=true;
          PROTON_PRIORITY_HIGH=true;

          PROTON_FSR4_UPGRADE = cgpu.vendor == "amd"
                                && cgpu.generation == "rdna4";
          PROTON_FSR4_RDNA3_UPGRADE = cgpu.vendor == "amd"
                                      && cgpu.generation == "rdna3"
                                      && cfg.force-fsr4-for-rdna3;
          PROTON_FSR3_UPGRADE = cgpu.generation == "rdna3"
                                && (!cfg.force-fsr4-for-rdna3);
          PROTON_DLSS_UPGRADE = cgpu.vendor == "nvidia";
          PROTON_XESS_UPGRADE = cgpu.vendor == "intel"
                                || (cgpu.vendor == "amd"
                                    && cgpu.generation != "rdna4");

          # PROTON_ENABLE_WAYLAND = cgpu.vendor == "amd" || cfg.enableHDR;
          PROTON_ENABLE_HDR = cfg.enableHDR;
          DXVK_HDR = cfg.enableHDR;
          ENABLE_HDR_WSI = cfg.enableHDR;
        } //
        (if cfg.lsfg.enable == true then {
          VK_LAYER_PATH= "${lsfg-vk}/share/vulkan/explicit_layer.d";
          LSFG_LEGACY=1;
          ENABLE_LSFG=cfg.lsfg.activate_on_all_games;
          LSFG_MULTIPLIER=lib.mkIf cfg.lsfg.activate_on_all_games 2;
        } else {})
        // (if cfg.lsfg.enable == true
          && cfg.lsfg.steam_library_for_lossless_scaling != null then {
          LSFG_DLL_PATH="${cfg.lsfg.steam_library_for_lossless_scaling}/steamapps/common/Lossless Scaling/Lossless.dll";
        } else {});
        extraProfile = ''
          export TZ="$(timedatectl show -p Timezone --value)"
        '';
      });
    };

    environment.systemPackages = [
      pkgs.adwsteamgtk
    ]
    ++ lib.optional cfg.lsfg.enable lsfg-vk-ui-fhs;

    system.activationScripts.steamConfigInject = {
      text = ''
        for user in /home/*; do
          steam_path="$user/.local/share/Steam"
          config_path="$steam_path/config"
          config_file="$config_path/config.vdf"
          mkdir -p "$config_path"
          if [ ! -f "$config_file" ]; then
            cat > "$config_file" <<EOF
        "InstallConfigStore"
        {
        "Software"
        {
          "Valve"
          {
              "Steam"
              {
                  "CompatToolMapping"
                  {
                      "0"
                      {
                          "name"      "GE-Proton"
                          "config"        ""
                          "priority"      "75"
                      }
                  }
                  "ShaderCacheManager"
                  {
                      "EnableShaderBackgroundProcessing"          "1"
                      "DisableShaderCache"		"0"
                  }
              }
          }
        }
        }
        EOF
            chown -R $(basename "$user"):users "$steam_path"
          fi
        done
      '';
    };
  };
}
