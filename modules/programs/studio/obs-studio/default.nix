{ config, lib, pkgs, ... }:

let
  cfg = config.mx.programs.studio.obs-studio;
  cgpu = config.mx.hardware.gpu;
  gamesEnabled = config.mx.programs.games.enable;
in
{
  options.mx.programs.studio.obs-studio = {
    enable = lib.mkEnableOption "Enable OBS Studio";
  };

  config = lib.mkIf cfg.enable {
    mx.programs._studio.enable = true;
    mx.hardware.gpu.compute.enable = true;
    mx.fonts.enable = true;
    programs.obs-studio = {
      enable = true;
      enableVirtualCamera = lib.mkMxDefault true;
      package = lib.mkMxDefault (
        if cgpu.vendor != "nvidia" then
          pkgs.obs-studio
        else
          pkgs.obs-studio.override { cudaSupport = true; }
      );
      plugins = with pkgs.obs-studio-plugins; [
        obs-move-transition
      ] ++ lib.optional (cgpu.vendor != "nvidia") pkgs.obs-studio-plugins.obs-vaapi
       ++ lib.optional gamesEnabled pkgs.obs-studio-plugins.obs-vkcapture;
    };

    # obs-gamecapture must also be reachable outside the OBS plugin dir: mx-games
    # wraps the game with it, and Steam needs it inside its FHS environment.
    environment.systemPackages =
      lib.optional gamesEnabled pkgs.obs-studio-plugins.obs-vkcapture;

    programs.steam.extraPackages =
      lib.optional gamesEnabled pkgs.obs-studio-plugins.obs-vkcapture;
  };
}
