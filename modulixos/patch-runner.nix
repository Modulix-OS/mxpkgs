{ config, lib, self, pkgs, ... }:

let
  cfg = config.mx.services.patch-runner;


  runner = self.packages.${pkgs.stdenv.hostPlatform.system}.patch-runner;

  repo = "Modulix-OS/mxpkgs";
  ref = "main";
  publicKey = "RWSoHPUVbpAR+kg76ayyuzTTzxgVbSuIzUI7CQTOQ7spbWLkyBouU9NS";
  base = "https://raw.githubusercontent.com/${repo}/refs/heads/${ref}/patches";
  current_version = 2;

in
{
  options.mx.services.patch-runner = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Modulix OS remote hotfix runner";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      description = "systemd OnCalendar expression for the periodic check.";
    };

    runOnActivation = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Also trigger a (non-blocking) patch check after each system activation.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.patch-runner = {
      description = "Modulix OS remote hotfix runner";
      after = [ "network-online.target" ];

      restartIfChanged = false;
      stopIfChanged = false;

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${runner}";
        Restart = "on-failure";
        RestartSec = "60s";
        StartLimitBurst = 5;
        User = "root";
        StateDirectory = "patch-runner";
        StateDirectoryMode = "0700";
        TimeoutStartSec = 300;
        UMask = "0077";

        Environment = [
          "BASE=${base}"
          "PUBKEY=${publicKey}"
          "CURRENT_VERSION=${toString current_version}"
        ];

        PrivateTmp = true;
        ProtectControlGroups = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectClock = true;
        ProtectHostname = true;
        RestrictSUIDSGID = true;
        RestrictRealtime = true;
        RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK" ];
        LockPersonality = true;
        SystemCallArchitectures = "native";

        Nice = 10;
        IOSchedulingClass = "idle";
      };
    };

    systemd.timers.patch-runner = {
      description = "Periodic Modulix OS hotfix check";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2min";          # remplace le démarrage via multi-user.target
        OnCalendar = cfg.interval;
        Persistent = true;
        RandomizedDelaySec = 600;
      };
    };
  };
}
