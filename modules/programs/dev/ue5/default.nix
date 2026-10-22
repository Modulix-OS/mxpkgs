{ pkgs, config, lib, ... }:

let
  cfg = config.mx.programs.dev.ue5;
  gpu = config.mx.hardware.gpu;

  ue5 = import ../../../../pkgs/mx-ue5.nix {
    inherit pkgs;
    inherit (cfg) image installDir nvidia additionalPackages;
    prefersDgpu = gpu.hybrid.enable;
  };
in
{
  options.mx.programs.dev.ue5 = {
    enable = lib.mkEnableOption "Enable the Unreal Engine 5 editor, installed from an Epic archive into a dedicated Distrobox container";

    image = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/library/ubuntu:26.04";
      example = "docker.io/library/ubuntu:24.04";
      description = ''
        OCI image the Unreal Engine container is created from. The editor draws
        with Vulkan and reads its driver from inside the container, not from the
        host, so the release chosen here decides which Mesa the engine sees:
        26.04 carries Mesa 26, which is what the editor asks for, while 22.04
        carries Mesa 23.2 and makes it open a bad-driver warning on RDNA 3 and
        newer cards. Pinned to a release rather than latest because the apt
        dependency list the installer runs is written against these package
        names, and apt installs nothing at all when one of them does not
        resolve. Fully qualified on purpose, for the same reason as
        mx.programs.dev.distrobox.image: podman stops on an interactive menu
        when a short name is ambiguous. The image is pulled the first time the
        launcher runs, never at install time.
      '';
    };

    installDir = lib.mkOption {
      type = lib.types.str;
      default = "$HOME/.local/share/ue5";
      example = "$HOME/games/UnrealEngine5";
      description = ''
        Directory the Unreal Engine archive is extracted into. Expanded by the
        launcher's shell, so $HOME and other variables are allowed; it must
        stay inside the home directory, which the container shares with the
        host. A full engine takes well over 100 GB once extracted.
      '';
    };

    nvidia = lib.mkOption {
      type = lib.types.bool;
      default = gpu.dedicated.vendor == "nvidia" && !gpu.nvidia.disable;
      defaultText = lib.literalMD "true when the dedicated GPU slot declares nvidia and the card is not disabled";
      description = ''
        Pass --nvidia to distrobox when the container is created, which bind
        mounts the host driver into it. The flag fails on a machine without an
        NVIDIA card, so the default follows the detected hardware rather than
        being always on.
      '';
    };

    additionalPackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "clang-15" "ninja-build" ];
      description = ''
        Extra Ubuntu packages handed to distrobox at container creation, on top
        of the editor's own runtime dependencies. This is where a C++ toolchain
        for packaging a project belongs, since the engine's build scripts run
        inside the container and not on the host.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    warnings = lib.optional
      (builtins.match ".*:(1[0-9]|2[0-3])\\.(04|10)(-.*)?" cfg.image != null)
      ''
        mx.programs.dev.ue5.image is set to "${cfg.image}". Ubuntu releases older
        than 24.04 ship a Mesa the editor rejects on RDNA 3 and newer cards, and
        several of the dependency package names the installer asks for only exist
        from 24.04 on. The installer falls back to installing them one by one and
        only fails on the ones the editor cannot start without, but the graphics
        driver warning remains. Use 24.04 or later.
      '';

    mx.programs.dev.distrobox.enable = lib.mkMxDefault true;

    hardware.nvidia-container-toolkit.enable =
      lib.mkIf cfg.nvidia (lib.mkMxDefault true);

    environment.systemPackages = [ ue5 ];
  };
}
