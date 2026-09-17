{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.mx.services.modulix-daemon;

  configDir = "/etc/modulix-os";
  vmResultDir = "${config.users.users.${cfg.testUser}.home}/modulix-vm";

  cacheDir = "${configDir}/.cache";

  moduleIndexFiles = {
    "index.json" = ../../modules/index.json;
    "index.fr.json" = ../../modules/index.fr.json;
  };

  installModuleIndex = pkgs.writeShellScript "modulix-install-module-index" ''
    set -euo pipefail
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: src: ''
      install -Dm644 ${src} "${cacheDir}/${name}"
    '') moduleIndexFiles)}
  '';

  mx-init = inputs.modulix-core-utils.packages.${pkgs.stdenv.hostPlatform.system}.mx-init;

  mx-init-test = pkgs.writeShellScriptBin "mx-init-test" ''
    set -euo pipefail

    if [ "$(id -u)" -ne 0 ]; then
      echo "mx-init-test: must run as root (writes ${configDir})" >&2
      exit 1
    fi

    export PATH="${lib.makeBinPath [ pkgs.git config.nix.package ]}:/run/current-system/sw/bin:$PATH"

    mkdir -p "${vmResultDir}"
    cd "${vmResultDir}"

    ${mx-init}/bin/mx-init --debug \
      --config-dir "${configDir}" \
      --root / \
      --hostname modulix-test \
      --username ${cfg.testUser} --fullname "Modulix Test User" \
      --desktop gnome --locale fr_FR.UTF-8 --timezone Europe/Paris \
      --kb-layout fr --kb-variant "" --console-keymap fr "$@"

    chown -R ${cfg.testUser}:users "${vmResultDir}"
  '';
in
{
  options.mx.services.modulix-daemon = {
    enable = lib.mkOption {
      type        = lib.types.bool;
      default     = true;
      description = "Enable the Modulix OS daemon";
    };

    package = lib.mkOption {
      type        = lib.types.package;
      default     =
        let p = inputs.modulix-daemon.packages.${pkgs.stdenv.hostPlatform.system};
        in if cfg.testMode then p.mx-daemon-test else p.default;
      description = "Modulix daemon package";
    };

    testMode = lib.mkEnableOption "test mode: debug build, nixos-rebuild build-vm, isolated config dir";

    testUser = lib.mkOption {
      type        = lib.types.str;
      description = ''
        User whose home receives the `result` symlink of the VMs built in test
        mode. Required when testMode is enabled.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    nix.registry.nixpkgs.flake = inputs.nixpkgs;
    nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];

    systemd.tmpfiles.rules = lib.optionals cfg.testMode [
      "d ${vmResultDir} 0755 ${cfg.testUser} users -"
    ];

    systemd.services.modulix-daemon = {
      description = "Modulix OS daemon";
      after       = [ "dbus.service" "polkit.service" ];
      requires    = [ "dbus.service" ];
      wantedBy    = [ "multi-user.target" ];

      path = [
        config.nix.package
        pkgs.git
        "/run/current-system/sw"
      ];

      serviceConfig = {
        Type            = "dbus";
        BusName         = "org.modulix.Daemon";
        ExecStart       = "${cfg.package}/bin/mx-daemon";
        User            = "root";
        Restart         = "on-failure";
        RestartSec      = 5;
        StandardOutput  = "journal";
        StandardError   = "journal";
        SyslogIdentifier = "modulix-daemon";
        # configDir is wiped and re-created by mx-init, so the index files have
        # to be put back before the daemon reads them.
        ExecStartPre = "${installModuleIndex}";
      } // lib.optionalAttrs cfg.testMode {
        WorkingDirectory = vmResultDir;
      };

      environment = {
        RUST_LOG = if cfg.testMode then "debug" else "info";
        MX_CACHE_DIR = cacheDir;
      } // lib.optionalAttrs cfg.testMode {
        MX_DAEMON_CONFIG_DIR = "${configDir}/";
        MX_DAEMON_DRY_RUN    = "0";
      };
    };

    services.dbus.packages = [ cfg.package ];
    environment.systemPackages = [ cfg.package ]
      ++ lib.optional cfg.testMode mx-init-test;

    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id === "org.modulix.daemon.install" ||
            action.id === "org.modulix.daemon.remove") {

          if (subject.isInGroup("wheel")) {
            return polkit.Result.AUTH_SELF_KEEP;
          }

          return polkit.Result.AUTH_ADMIN_KEEP;
        }
      });
    '';
  };
}
