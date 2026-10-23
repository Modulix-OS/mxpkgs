{
  lib,
  config,
  options,
  ...
}:
let
  cfg = config.mx.security.hardening;

  unusedNetProtocols = [
    "dccp"
    "sctp"
    "rds"
    "tipc"
  ];

  forcedModule =
    m:
    builtins.elem m config.boot.kernelModules
    || builtins.elem m config.boot.initrd.kernelModules
    || builtins.elem m config.boot.initrd.availableKernelModules;
in
{
  options.mx.security.hardening = {
    enable = lib.mkOption {
      description = ''
        Enable the baseline hardening derived from the Lynis audit. This is
        permanent attack-surface reduction with no expiry; time-limited fixes for
        specific CVEs belong in mx.security.mitigations instead.
      '';
      type = lib.types.bool;
      default = true;
    };
    sysctl = lib.mkOption {
      description = "Apply the zero-cost hardening sysctl set (suid_dumpable, protected_fifos/regular, ICMP redirects, rp_filter).";
      type = lib.types.bool;
      default = true;
    };
    restrictSysrq = lib.mkOption {
      description = "Set kernel.sysrq to 4 (secure attention key only). Disables the SysRq rescue combos such as REISUB.";
      type = lib.types.bool;
      default = true;
    };
    disableLdiscAutoload = lib.mkOption {
      description = "Set dev.tty.ldisc_autoload to 0. Blocks automatic line discipline module loading; disable it on machines using UART bluetooth, PPP or SLIP.";
      type = lib.types.bool;
      default = true;
    };
    logMartians = lib.mkOption {
      description = "Log IPv4 packets with impossible source addresses. Increases log volume on noisy networks.";
      type = lib.types.bool;
      default = true;
    };
    blacklistUnusedNetProtocols = lib.mkOption {
      description = "Blacklist dccp, sctp, rds and tipc, which are autoloadable by an unprivileged socket() call and unused on a desktop.";
      type = lib.types.bool;
      default = true;
    };

    journal = {
      limit = lib.mkOption {
        description = "Bound the systemd journal size and retention.";
        type = lib.types.bool;
        default = true;
      };
      maxUse = lib.mkOption {
        description = ''
          Value of journald SystemMaxUse. Written through services.journald.settings.Journal
          where nixpkgs provides it, and through services.journald.extraConfig on the
          releases that still carry the old option.
        '';
        type = lib.types.str;
        default = "500M";
      };
      maxRetention = lib.mkOption {
        description = "Value of journald MaxRetentionSec.";
        type = lib.types.str;
        default = "1month";
      };
    };

    passwordAging = {
      enable = lib.mkOption {
        description = "Declare password aging in /etc/login.defs. Off by default: forced expiry is discouraged by NIST SP 800-63B and only satisfies the audit check.";
        type = lib.types.bool;
        default = false;
      };
      maxDays = lib.mkOption {
        description = "Value of PASS_MAX_DAYS.";
        type = lib.types.ints.positive;
        default = 365;
      };
      minDays = lib.mkOption {
        description = "Value of PASS_MIN_DAYS.";
        type = lib.types.ints.unsigned;
        default = 1;
      };
      warnAge = lib.mkOption {
        description = "Value of PASS_WARN_AGE.";
        type = lib.types.ints.unsigned;
        default = 14;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernel.sysctl = lib.mkMerge [
      (lib.mkIf cfg.sysctl {
        "fs.suid_dumpable" = lib.mkMxDefault 0;
        "fs.protected_fifos" = lib.mkMxDefault 2;
        "fs.protected_regular" = lib.mkMxDefault 2;
        "net.ipv4.conf.all.accept_redirects" = lib.mkMxDefault 0;
        "net.ipv4.conf.default.accept_redirects" = lib.mkMxDefault 0;
        "net.ipv6.conf.all.accept_redirects" = lib.mkMxDefault 0;
        "net.ipv6.conf.default.accept_redirects" = lib.mkMxDefault 0;
        "net.ipv4.conf.all.send_redirects" = lib.mkMxDefault 0;
        "net.ipv4.conf.default.send_redirects" = lib.mkMxDefault 0;
        "net.ipv4.conf.all.rp_filter" = lib.mkMxDefault 2;
      })
      (lib.mkIf cfg.restrictSysrq {
        "kernel.sysrq" = lib.mkMxDefault 4;
      })
      (lib.mkIf cfg.disableLdiscAutoload {
        "dev.tty.ldisc_autoload" = lib.mkMxDefault 0;
      })
      (lib.mkIf cfg.logMartians {
        "net.ipv4.conf.all.log_martians" = lib.mkMxDefault 1;
        "net.ipv4.conf.default.log_martians" = lib.mkMxDefault 1;
      })
    ];

    boot.blacklistedKernelModules = lib.genAttrs (
      lib.optionals cfg.blacklistUnusedNetProtocols unusedNetProtocols
    ) (_: true);

    services.journald = lib.mkIf cfg.journal.limit (
      if options.services.journald ? settings then
        {
          settings.Journal = {
            SystemMaxUse = lib.mkMxDefault cfg.journal.maxUse;
            MaxRetentionSec = lib.mkMxDefault cfg.journal.maxRetention;
          };
        }
      else
        {
          extraConfig = ''
            SystemMaxUse=${cfg.journal.maxUse}
            MaxRetentionSec=${cfg.journal.maxRetention}
          '';
        }
    );

    security.loginDefs.settings = lib.mkIf cfg.passwordAging.enable {
      PASS_MAX_DAYS = lib.mkMxDefault cfg.passwordAging.maxDays;
      PASS_MIN_DAYS = lib.mkMxDefault cfg.passwordAging.minDays;
      PASS_WARN_AGE = lib.mkMxDefault cfg.passwordAging.warnAge;
    };

    assertions = [
      {
        assertion = cfg.blacklistUnusedNetProtocols -> !(lib.any forcedModule unusedNetProtocols);
        message = ''
          mx.security.hardening.blacklistUnusedNetProtocols = true but one of
          ${lib.concatStringsSep "/" unusedNetProtocols} is forced via
          boot.kernelModules or boot.initrd.{kernelModules,availableKernelModules}.
          Set mx.security.hardening.blacklistUnusedNetProtocols = false if you
          need it.
        '';
      }
    ];
  };
}
