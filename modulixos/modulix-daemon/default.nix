{ config, lib, ... }:

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
      description = "Modulix daemon package";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.modulix-daemon = {
      description = "Modulix OS daemon";
      after       = [ "dbus.service" "polkit.service" ];
      requires    = [ "dbus.service" ];
      wantedBy    = [ "multi-user.target" ];

      serviceConfig = {
        Type            = "dbus";
        BusName         = "org.modulix.Daemon";
        ExecStart       = "${cfg.package}/bin/modulix-daemon";
        User            = "root";
        Restart         = "on-failure";
        RestartSec      = 5;
        StandardOutput  = "journal";
        StandardError   = "journal";
        SyslogIdentifier = "modulix-daemon";
      };

      environment = {
        RUST_LOG = "info";
      };
    };

    services.dbus.packages = [ cfg.package ];
    environment.systemPackages = [ cfg.package ];

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
