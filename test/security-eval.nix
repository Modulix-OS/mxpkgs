{ lib, pkgs, baseSystem }:

let
  ov = v: { _type = "override"; priority = 50; content = v; };

  cfgOf = mod: (baseSystem.extendModules { modules = [ mod ]; }).config;

  mit = m: { mx.security.mitigations = m; };
  hard = h: { mx.security.hardening = h; };

  mxFailures =
    c:
    lib.filter (m: lib.hasInfix "mx.security" m) (
      map (a: a.message) (lib.filter (a: !a.assertion) c.assertions)
    );

  failsWith = c: pat: lib.any (m: lib.hasInfix pat m) (mxFailures c);
  mxWarnings = c: lib.filter (m: lib.hasInfix "mx.security" m) c.warnings;
  blacklisted = c: lib.sort (a: b: a < b) c.boot.blacklistedKernelModules;
  sysctl = c: n: c.boot.kernel.sysctl.${n} or null;
  hasSysctl = c: n: c.boot.kernel.sysctl ? ${n};
  modprobe = c: c.boot.extraModprobeConfig;
  journalLimited = c:
    lib.hasInfix "SystemMaxUse=500M" (c.services.journald.extraConfig or "")
    || (c.services.journald.settings.Journal.SystemMaxUse or null) == "500M";
  journalRetained = c:
    lib.hasInfix "MaxRetentionSec=1month" (c.services.journald.extraConfig or "")
    || (c.services.journald.settings.Journal.MaxRetentionSec or null) == "1month";

  c = {
    base = cfgOf { };
    mitOff = cfgOf (mit { enable = false; });
    hardOff = cfgOf (hard { enable = false; });

    espOff = cfgOf (mit { blacklistEsp = false; });
    rxrpcOff = cfgOf (mit { blacklistRxrpc = false; });
    ipcompOff = cfgOf (mit { blacklistIpcomp = false; });
    algifOff = cfgOf (mit { blacklistAlgifAead = false; });

    ipsec = cfgOf { services.strongswan.enable = true; };
    ipsecOk = cfgOf {
      services.strongswan.enable = true;
      mx.security.mitigations = {
        blacklistEsp = false;
        blacklistIpcomp = false;
      };
    };
    swanctl = cfgOf { services.strongswan-swanctl.enable = true; };
    libreswan = cfgOf { services.libreswan.enable = true; };
    nmIpsec = cfgOf { networking.networkmanager.plugins = [ pkgs.networkmanager-l2tp ]; };

    kafs = cfgOf { boot.kernelModules = [ "kafs" ]; };
    kafsOk = cfgOf {
      boot.kernelModules = [ "kafs" ];
      mx.security.mitigations.blacklistRxrpc = false;
    };
    espForced = cfgOf { boot.kernelModules = [ "esp4" ]; };
    espForcedInitrd = cfgOf { boot.initrd.kernelModules = [ "esp6" ]; };
    sctpForced = cfgOf { boot.kernelModules = [ "sctp" ]; };

    ptraceOff = cfgOf (mit { restrictPtraceScope = false; });
    ptrace2 = cfgOf (mit { ptraceScope = 2; });
    hardDisable = cfgOf (mit { hardDisable = true; });

    expired = cfgOf (mit { fixedInKernel.esp = "0.0.1"; });
    notExpired = cfgOf (mit { fixedInKernel.esp = "99.0"; });
    badKey = cfgOf (mit { fixedInKernel.nope = "1.0"; });

    noProtoBlacklist = cfgOf (hard { blacklistUnusedNetProtocols = false; });
    noSysrq = cfgOf (hard { restrictSysrq = false; });
    noLdisc = cfgOf (hard { disableLdiscAutoload = false; });
    noMartians = cfgOf (hard { logMartians = false; });
    noJournal = cfgOf (hard { journal.limit = false; });
    aging = cfgOf (hard { passwordAging.enable = true; });
    userSysrq = cfgOf { boot.kernel.sysctl."kernel.sysrq" = ov 0; };
    unblacklistEsp = cfgOf { boot.blacklistedKernelModules.esp4 = ov false; };
  };

  results = lib.mapAttrs (_: cc: {
    blacklist = blacklisted cc;
    ptraceScope = sysctl cc "kernel.yama.ptrace_scope";
    sysrq = sysctl cc "kernel.sysrq";
    journalLimited = journalLimited cc;
    failures = mxFailures cc;
    warnings = mxWarnings cc;
  }) c;

  expect =
    name: got: want:
    if got == want then
      true
    else
      throw "security-eval [${name}]: got ${builtins.toJSON got}, expected ${builtins.toJSON want}";

  checks = [
    (expect "base.blacklist" (blacklisted c.base) [
      "algif_aead"
      "dccp"
      "esp4"
      "esp6"
      "ipcomp4"
      "ipcomp6"
      "rds"
      "rxrpc"
      "sctp"
      "tipc"
    ])
    (expect "base.noFailures" (mxFailures c.base) [ ])
    (expect "base.noWarnings" (mxWarnings c.base) [ ])

    (expect "mitOff.blacklist" (blacklisted c.mitOff) [
      "dccp"
      "rds"
      "sctp"
      "tipc"
    ])
    (expect "hardOff.blacklist" (blacklisted c.hardOff) [
      "algif_aead"
      "esp4"
      "esp6"
      "ipcomp4"
      "ipcomp6"
      "rxrpc"
    ])

    (expect "espOff.noEsp4" (lib.elem "esp4" (blacklisted c.espOff)) false)
    (expect "espOff.keepsRxrpc" (lib.elem "rxrpc" (blacklisted c.espOff)) true)
    (expect "rxrpcOff.noRxrpc" (lib.elem "rxrpc" (blacklisted c.rxrpcOff)) false)
    (expect "rxrpcOff.keepsEsp4" (lib.elem "esp4" (blacklisted c.rxrpcOff)) true)
    (expect "ipcompOff.noIpcomp4" (lib.elem "ipcomp4" (blacklisted c.ipcompOff)) false)
    (expect "algifOff.noAlgif" (lib.elem "algif_aead" (blacklisted c.algifOff)) false)

    (expect "ipsec.espFails" (failsWith c.ipsec "blacklistEsp = true") true)
    (expect "ipsec.ipcompFails" (failsWith c.ipsec "blacklistIpcomp = true") true)
    (expect "ipsecOk.noFailures" (mxFailures c.ipsecOk) [ ])
    (expect "swanctl.espFails" (failsWith c.swanctl "blacklistEsp = true") true)
    (expect "libreswan.espFails" (failsWith c.libreswan "blacklistEsp = true") true)
    (expect "nmIpsec.espFails" (failsWith c.nmIpsec "blacklistEsp = true") true)

    (expect "kafs.rxrpcFails" (failsWith c.kafs "blacklistRxrpc = true") true)
    (expect "kafsOk.noFailures" (mxFailures c.kafsOk) [ ])
    (expect "espForced.fails" (failsWith c.espForced "esp4/esp6 is forced") true)
    (expect "espForcedInitrd.fails" (failsWith c.espForcedInitrd "esp4/esp6 is forced") true)
    (expect "sctpForced.fails" (failsWith c.sctpForced "dccp/sctp/rds/tipc is forced") true)

    (expect "base.ptrace" (sysctl c.base "kernel.yama.ptrace_scope") 1)
    (expect "ptrace2.value" (sysctl c.ptrace2 "kernel.yama.ptrace_scope") 2)
    (expect "ptraceOff.absent" (hasSysctl c.ptraceOff "kernel.yama.ptrace_scope") false)

    (expect "base.noInstallRules" (lib.hasInfix "install esp4" (modprobe c.base)) false)
    (expect "hardDisable.esp4" (lib.hasInfix "install esp4 " (modprobe c.hardDisable)) true)
    (expect "hardDisable.rxrpc" (lib.hasInfix "install rxrpc " (modprobe c.hardDisable)) true)
    (expect "hardDisable.notSctp" (lib.hasInfix "install sctp " (modprobe c.hardDisable)) false)

    (expect "expired.warns" (lib.length (mxWarnings c.expired)) 1)
    (expect "expired.mentionsCve" (lib.any (m: lib.hasInfix "CVE-2026-43284" m) (mxWarnings c.expired)) true)
    (expect "notExpired.silent" (mxWarnings c.notExpired) [ ])
    (expect "badKey.fails" (failsWith c.badKey "unknown keys") true)

    (expect "base.suidDumpable" (sysctl c.base "fs.suid_dumpable") 0)
    (expect "base.protectedRegular" (sysctl c.base "fs.protected_regular") 2)
    (expect "base.rpFilter" (sysctl c.base "net.ipv4.conf.all.rp_filter") 2)
    (expect "base.redirects" (sysctl c.base "net.ipv6.conf.default.accept_redirects") 0)
    (expect "base.sysrq" (sysctl c.base "kernel.sysrq") 4)
    (expect "base.ldisc" (sysctl c.base "dev.tty.ldisc_autoload") 0)
    (expect "base.martians" (sysctl c.base "net.ipv4.conf.all.log_martians") 1)
    (expect "hardOff.noSuid" (hasSysctl c.hardOff "fs.suid_dumpable") false)
    (expect "noSysrq.absent" (hasSysctl c.noSysrq "kernel.sysrq") false)
    (expect "noLdisc.absent" (hasSysctl c.noLdisc "dev.tty.ldisc_autoload") false)
    (expect "noMartians.absent" (hasSysctl c.noMartians "net.ipv4.conf.all.log_martians") false)
    (expect "userSysrq.wins" (sysctl c.userSysrq "kernel.sysrq") 0)
    (expect "noProtoBlacklist.noSctp" (lib.elem "sctp" (blacklisted c.noProtoBlacklist)) false)
    (expect "unblacklistEsp.noEsp4" (lib.elem "esp4" (blacklisted c.unblacklistEsp)) false)
    (expect "unblacklistEsp.keepsEsp6" (lib.elem "esp6" (blacklisted c.unblacklistEsp)) true)

    (expect "base.journalMaxUse" (journalLimited c.base) true)
    (expect "base.journalRetention" (journalRetained c.base) true)
    (expect "noJournal.absent" (journalLimited c.noJournal) false)

    (expect "base.noPassAging" (c.base.security.loginDefs.settings ? PASS_MAX_DAYS) false)
    (expect "aging.maxDays" c.aging.security.loginDefs.settings.PASS_MAX_DAYS 365)
    (expect "aging.minDays" c.aging.security.loginDefs.settings.PASS_MIN_DAYS 1)
    (expect "aging.warnAge" c.aging.security.loginDefs.settings.PASS_WARN_AGE 14)
  ];

  allOk = lib.all (x: x == true) checks;

  check =
    assert allOk;
    pkgs.runCommand "security-eval" { } ''
      echo "security-eval: ${toString (lib.length checks)} assertions passed"
      touch $out
    '';
in
{
  inherit results check;
}
