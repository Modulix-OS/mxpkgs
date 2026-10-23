{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.mx.security.mitigations;

  kernelVersion = config.boot.kernelPackages.kernel.version;

  groups = {
    esp = {
      option = "blacklistEsp";
      enabled = cfg.blacklistEsp;
      modules = [
        "esp4"
        "esp6"
      ];
      cve = "CVE-2026-43284";
      fixedIn = cfg.fixedInKernel.esp or null;
    };
    rxrpc = {
      option = "blacklistRxrpc";
      enabled = cfg.blacklistRxrpc;
      modules = [ "rxrpc" ];
      cve = "CVE-2026-43500";
      fixedIn = cfg.fixedInKernel.rxrpc or null;
    };
    algifAead = {
      option = "blacklistAlgifAead";
      enabled = cfg.blacklistAlgifAead;
      modules = [ "algif_aead" ];
      cve = "CVE-2026-31431";
      fixedIn = cfg.fixedInKernel.algifAead or null;
    };
    ipcomp = {
      option = "blacklistIpcomp";
      enabled = cfg.blacklistIpcomp;
      modules = [
        "ipcomp4"
        "ipcomp6"
      ];
      cve = "CVE-2026-46300";
      fixedIn = cfg.fixedInKernel.ipcomp or null;
    };
  };

  activeGroups = lib.filterAttrs (_: g: g.enabled) groups;

  blacklistedModules = lib.concatMap (g: g.modules) (lib.attrValues activeGroups);

  forcedModule =
    m:
    builtins.elem m config.boot.kernelModules
    || builtins.elem m config.boot.initrd.kernelModules
    || builtins.elem m config.boot.initrd.availableKernelModules;

  anyForced = ms: lib.any forcedModule ms;

  ipsecServices =
    config.services.strongswan.enable
    || config.services.strongswan-swanctl.enable
    || config.services.libreswan.enable
    || lib.any (
      p: lib.hasInfix "strongswan" (p.pname or p.name or "") || lib.hasInfix "l2tp" (p.pname or p.name or "")
    ) config.networking.networkmanager.plugins;

  kafsInUse =
    builtins.elem "kafs" config.boot.kernelModules
    || lib.any (fs: fs.fsType == "afs") (lib.attrValues config.fileSystems);

  mkForcedAssertion = g: {
    assertion = g.enabled -> !(anyForced g.modules);
    message = ''
      mx.security.mitigations.${g.option} = true (${g.cve}) but one of
      ${lib.concatStringsSep "/" g.modules} is forced via boot.kernelModules or
      boot.initrd.{kernelModules,availableKernelModules}.
      Set mx.security.mitigations.${g.option} = false if you need it.
    '';
  };
in
{
  imports = [
    (lib.mkRemovedOptionModule [ "mx" "security" "mitigations" "blacklistDirtyFrag" ] ''
      Split into mx.security.mitigations.blacklistEsp (esp4/esp6, CVE-2026-43284)
      and mx.security.mitigations.blacklistRxrpc (rxrpc, CVE-2026-43500), because
      blacklisting esp4/esp6 breaks IPsec while blacklisting rxrpc costs nothing
      on a desktop.
    '')
    (lib.mkRemovedOptionModule [ "mx" "security" "mitigations" "blacklistCopyFail" ] ''
      Renamed to mx.security.mitigations.blacklistAlgifAead (CVE-2026-31431).
    '')
    (lib.mkRemovedOptionModule [ "mx" "security" "mitigations" "blacklistFragnesia" ] ''
      Renamed to mx.security.mitigations.blacklistIpcomp (CVE-2026-46300).
    '')
    (lib.mkRemovedOptionModule [ "mx" "security" "mitigations" "mitigateSshKeysignPwn" ] ''
      Renamed to mx.security.mitigations.restrictPtraceScope, and the value is now
      set by mx.security.mitigations.ptraceScope (default 1 instead of 2).
    '')
  ];

  options.mx.security.mitigations = {
    enable = lib.mkOption {
      description = ''
        Enable the mitigations for known kernel and userspace CVEs that are not
        yet fixed in the pinned package set. These are temporary: each one is
        meant to be dropped once the fix lands, which mx.security.mitigations.fixedInKernel
        turns into a build-time warning. Permanent attack-surface reduction belongs
        in mx.security.hardening instead.
      '';
      type = lib.types.bool;
      default = true;
    };
    blacklistEsp = lib.mkOption {
      description = ''
        Blacklist esp4/esp6 (CVE-2026-43284, https://nvd.nist.gov/vuln/detail/CVE-2026-43284).
        Breaks every IPsec tunnel: strongSwan, libreswan and the NetworkManager
        l2tp/strongswan VPN plugins. Turn it off if the machine uses an IPsec VPN.
      '';
      type = lib.types.bool;
      default = true;
    };
    blacklistRxrpc = lib.mkOption {
      description = ''
        Blacklist rxrpc (CVE-2026-43500, https://nvd.nist.gov/vuln/detail/CVE-2026-43500).
        Only the in-kernel AFS client (kafs) needs it, so this is free on a desktop.
      '';
      type = lib.types.bool;
      default = true;
    };
    blacklistAlgifAead = lib.mkOption {
      description = ''
        Blacklist algif_aead (CVE-2026-31431, https://nvd.nist.gov/vuln/detail/CVE-2026-31431).
        Only userspace AF_ALG AEAD consumers need it (libkcapi and friends).
      '';
      type = lib.types.bool;
      default = true;
    };
    blacklistIpcomp = lib.mkOption {
      description = ''
        Blacklist ipcomp4/ipcomp6 (CVE-2026-46300, https://nvd.nist.gov/vuln/detail/CVE-2026-46300).
        Disables IPsec payload compression; like blacklistEsp this affects IPsec setups.
      '';
      type = lib.types.bool;
      default = true;
    };
    restrictPtraceScope = lib.mkOption {
      description = ''
        Raise kernel.yama.ptrace_scope above the kernel default of 0, as a
        defence-in-depth measure against local ptrace-based privilege escalation
        such as CVE-2026-46333. Note that the setuid ssh-keysign helper that CVE
        targets is not shipped by NixOS, so on this distribution the setting is
        hardening rather than a fix: drop it once the pinned openssh carries the
        upstream patch.
      '';
      type = lib.types.bool;
      default = true;
    };
    ptraceScope = lib.mkOption {
      description = ''
        Value of kernel.yama.ptrace_scope when restrictPtraceScope is enabled.
        1 restricts attaching to descendants plus explicit PR_SET_PTRACER opt-ins,
        which is what Debian, Ubuntu and Fedora ship and what crash handlers
        (Chrome, Electron, Wine) rely on. 2 allows CAP_SYS_PTRACE only and breaks
        those opt-ins. 3 forbids attaching entirely. Either way `gdb -p` and
        `strace -p` on a non-descendant process need sudo.
      '';
      type = lib.types.ints.between 0 3;
      default = 1;
    };
    hardDisable = lib.mkOption {
      description = ''
        Also emit `install <module> false` modprobe rules for every blacklisted
        module. boot.blacklistedKernelModules only emits `blacklist` lines, which
        stop alias-driven autoload (the unprivileged socket() vector) but still let
        an explicit `modprobe esp4` through. Neither mechanism has any effect on a
        module built into the kernel (=y) rather than built as a module.
      '';
      type = lib.types.bool;
      default = false;
    };
    fixedInKernel = lib.mkOption {
      description = ''
        Kernel version that fixes each blacklist group, keyed by group name. Once
        the running kernel is at least that version the build emits a warning
        telling you to drop the mitigation, so these entries do not rot in the tree.
        null means no upstream fix is known yet.
      '';
      type = lib.types.attrsOf (lib.types.nullOr lib.types.str);
      default = {
        esp = null;
        rxrpc = null;
        algifAead = null;
        ipcomp = null;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    boot.blacklistedKernelModules = lib.genAttrs blacklistedModules (_: true);

    boot.extraModprobeConfig = lib.mkIf cfg.hardDisable (
      lib.concatMapStrings (m: "install ${m} ${pkgs.coreutils}/bin/false\n") blacklistedModules
    );

    boot.kernel.sysctl = lib.mkIf cfg.restrictPtraceScope {
      "kernel.yama.ptrace_scope" = lib.mkMxDefault cfg.ptraceScope;
    };

    warnings = lib.mapAttrsToList (
      _: g:
      "mx.security.mitigations: ${g.cve} is fixed in kernel ${g.fixedIn} and this system runs ${kernelVersion}. Set mx.security.mitigations.${g.option} = false and drop the entry."
    ) (lib.filterAttrs (_: g: g.fixedIn != null && lib.versionAtLeast kernelVersion g.fixedIn) activeGroups);

    assertions = lib.mapAttrsToList (_: mkForcedAssertion) groups ++ [
      {
        assertion = !(cfg.blacklistEsp && ipsecServices);
        message = ''
          mx.security.mitigations.blacklistEsp = true (CVE-2026-43284) but an IPsec
          stack is enabled (services.strongswan, services.strongswan-swanctl,
          services.libreswan or a NetworkManager l2tp/strongswan plugin). Blacklisting
          esp4/esp6 silently breaks every tunnel.
          Set mx.security.mitigations.blacklistEsp = false to keep IPsec.
        '';
      }
      {
        assertion = !(cfg.blacklistIpcomp && ipsecServices);
        message = ''
          mx.security.mitigations.blacklistIpcomp = true (CVE-2026-46300) but an IPsec
          stack is enabled. Blacklisting ipcomp4/ipcomp6 disables IPsec payload
          compression and breaks peers that negotiate it.
          Set mx.security.mitigations.blacklistIpcomp = false to keep IPsec.
        '';
      }
      {
        assertion = !(cfg.blacklistRxrpc && kafsInUse);
        message = ''
          mx.security.mitigations.blacklistRxrpc = true (CVE-2026-43500) but the
          in-kernel AFS client is in use (kafs in boot.kernelModules, or an "afs"
          entry in fileSystems), and it cannot work without rxrpc.
          Set mx.security.mitigations.blacklistRxrpc = false to keep AFS.
        '';
      }
      {
        assertion = lib.all (n: builtins.hasAttr n groups) (lib.attrNames cfg.fixedInKernel);
        message = ''
          mx.security.mitigations.fixedInKernel has unknown keys:
          ${lib.concatStringsSep ", " (lib.subtractLists (lib.attrNames groups) (lib.attrNames cfg.fixedInKernel))}.
          Valid keys are ${lib.concatStringsSep ", " (lib.attrNames groups)}.
        '';
      }
    ];
  };
}
