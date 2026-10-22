{ pkgs, config, lib, ... }:

let
  cfg = config.mx.programs.dev.distrobox;

  ubuntuBox = import ../../../../pkgs/mx-ubuntu-box.nix {
    inherit pkgs;
    inherit (cfg) image containerName icon;
  };
in
{
  options.mx.programs.dev.distrobox = {
    enable = lib.mkEnableOption "Enable Distrobox on a rootless Podman backend, with an Ubuntu container launcher";

    image = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/library/ubuntu:latest";
      example = "docker.io/library/ubuntu:26.04";
      description = ''
        OCI image the Ubuntu container is created from. Fully qualified on
        purpose: NixOS writes two unqualified search registries into
        /etc/containers/registries.conf, and podman stops on an interactive
        menu when a short name is ambiguous and a terminal is attached, which
        the launcher's desktop entry guarantees. The latest tag tracks the
        current Ubuntu LTS; pin a release tag to freeze it. The image is
        pulled the first time the launcher runs, never at install time, so a
        machine installed offline still gets a working system.
      '';
    };

    containerName = lib.mkOption {
      type = lib.types.str;
      default = "ubuntu";
      description = "Name of the container the launcher creates and enters.";
    };

    icon = lib.mkOption {
      type = lib.types.str;
      default = "distributor-logo-ubuntu";
      description = ''
        Icon name for the launcher's desktop entry. The default is the Papirus
        Ubuntu logo, which resolves because mx.branding.iconTheme merges
        Papirus into Adwaita.
      '';
    };

    dnsForContainers = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Name resolution between Podman containers. Distrobox does not need it,
        sharing the host network namespace, but it is what lets a hand-written
        podman run or a compose file reach its siblings by name. It costs one
        generated network file and UDP port 53 opened on the podman bridge.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.podman = {
      enable = true;
      defaultNetwork.settings = lib.mkIf cfg.dnsForContainers {
        dns_enabled = lib.mkMxDefault true;
      };
    };

    environment.systemPackages = [
      pkgs.distrobox
      ubuntuBox
    ];
  };
}
