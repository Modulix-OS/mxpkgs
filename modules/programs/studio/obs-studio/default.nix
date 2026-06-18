{ config, lib, pkgs, ... }:

let
  cfg = config.mx.programs.studio.obs-studio;
  cgpu = config.mx.hardware.gpu;
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
      enableVirtualCamera = true;
      package = (
        if cgpu.vendor != "nvidia" then
          pkgs.obs-studio
        else
          pkgs.obs-studio.override { cudaSupport = true; }
      );
      plugins = with pkgs.obs-studio-plugins; [
        obs-move-transition
      ] ++ lib.optional config.mx.programs.games.enable pkgs.obs-studio-plugins.obs-vkcapture;
    };
  };

}
 # -> modesetting driver, fine under virtio-gpu
