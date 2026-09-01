{ pkgs, lib, config, ... }:

let
  cgpu = config.mx.hardware.gpu;
  isGraphical = config.mx.desktop != "cli";
in
{
  imports = [
    ./gnome
    ./plasma
    ./lxqt
  ];

  options.mx.desktop = lib.mkOption {
    type = lib.types.enum [ "gnome" "plasma" "lxqt" "cli" ];
    default = "gnome";
    description = "Desktop environment (gnome, plasma, lxqt) or CLI-only (cli)";
  };

  # Shared graphical config for every desktop environment.
  config = lib.mkIf isGraphical {
    services.xserver = {
      enable = true;
      videoDrivers = [
        (
          if cgpu.vendor == "amd"
          then "amdgpu"
          else if cgpu.vendor == "nvidia" then
          cgpu.vendor
          else "modesetting"
        )
      ];
      excludePackages = with pkgs; [
        xterm
      ];
      xkb = {
        layout = lib.mkMxDefault "fr";
        variant = lib.mkMxDefault "";
      };
    };

    systemd.services."getty@tty1".enable = false;
    systemd.services."autovt@tty1".enable = false;
  };
}
