{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.mx.services.modulix-daemon;
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
      default     = inputs.modulix-daemon.packages.${pkgs.system}.default;
      description = "Modulix daemon package";
    };
  };

  config = lib.mkIf cfg.enable {
    nix.registry.nixpkgs.flake = inputs.nixpkgs;
    nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];

    systemd.services.modulix-daemon = {
      description = "Modulix OS daemon";
      after       = [ "dbus.service" "polkit.service" ];
      requires    = [ "dbus.service" ];
      wantedBy    = [ "multi-user.target" ];

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
        CacheDirectory     = "modulix";
        CacheDirectoryMode = "0755";
      };

      environment = {
        RUST_LOG = "info";
      };
    };

    services.dbus.packages = [ cfg.package ];
    environment.systemPackages = [ cfg.package ];

    environment.etc."modulix-os/modules/index.json".source = ../../modules/index.json;
    environment.etc."modulix-os/modules/index.fr.json".source = ../../modules/index.fr.json;

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
