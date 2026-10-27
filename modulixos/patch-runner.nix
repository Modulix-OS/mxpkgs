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
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      restartIfChanged = false;
      stopIfChanged = false;

      serviceConfig = {
        Type = "oneshot";
        ExecCondition = "${pkgs.writeShellScript "only-at-boot" ''
          case "$(${pkgs.systemd}/bin/systemctl is-system-running || true)" in
            initializing|starting) exit 0 ;;
            *) exit 1 ;;
          esac
        ''}";
        ExecStart = "${runner}";
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
        OnCalendar = cfg.interval;
        Persistent = true;
        RandomizedDelaySec = 600;
      };
    };

    system.activationScripts.patchRunnerTrigger = lib.mkIf cfg.runOnActivation {
      text = ''
        ${config.systemd.package}/bin/systemctl start --no-block patch-runner.service || true
      '';
    };
  };
}
