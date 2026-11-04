{ pkgs ? import <nixpkgs> {} }:

let
  busctl = "${pkgs.systemd}/bin/busctl";
  jq = "${pkgs.jq}/bin/jq";
  od = "${pkgs.coreutils}/bin/od";
  tr = "${pkgs.coreutils}/bin/tr";
  nixInstantiate = "${pkgs.nix}/bin/nix-instantiate";

  script = pkgs.writeShellScriptBin "mx-sbctl" ''
    set -euo pipefail

    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'

    efi_dir=/sys/firmware/efi
    efivars_dir=/sys/firmware/efi/efivars
    efi_guid=8be4df61-93ca-11d2-aa0d-00e098032b8c
    config_dir="''${MX_DAEMON_CONFIG_DIR:-/etc/modulix-os}"
    boot_nix="''${config_dir%/}/boot.nix"

    efivar_byte() {
      efivar_file="$efivars_dir/$1-$efi_guid"
      [ -r "$efivar_file" ] || return 1
      ${od} -An -tu1 -j4 -N1 "$efivar_file" | ${tr} -dc '0-9'
    }

    firmware_secure_boot() {
      if ! sb_byte=$(efivar_byte SecureBoot); then
        echo unknown
        return 0
      fi
      case "$sb_byte" in
        "") echo unknown ;;
        0) echo off ;;
        *) echo on ;;
      esac
    }

    firmware_keys() {
      if ! sm_byte=$(efivar_byte SetupMode); then
        echo unknown
        return 0
      fi
      case "$sm_byte" in
        "") echo unknown ;;
        0) echo user ;;
        *) echo setup ;;
      esac
    }

    declared_secure_boot() {
      if declared_raw=$(${nixInstantiate} --eval --expr \
            "((import $boot_nix { config = {}; lib = {}; pkgs = {}; }).mx.bootloader.secureBoot.enable or false)" \
            2>/dev/null); then
        case "$declared_raw" in
          true) echo enabled ;;
          false) echo disabled ;;
          *) echo unknown ;;
        esac
      else
        echo unknown
      fi
    }

    print_status() {
      if [ ! -d "$efi_dir" ]; then
        echo "Secure Boot: unavailable, this machine did not boot in UEFI mode"
        return 0
      fi

      status_firmware=$(firmware_secure_boot)
      status_keys=$(firmware_keys)
      status_declared=$(declared_secure_boot)

      case "$status_firmware" in
        on) echo -e "Firmware Secure Boot:  ''${GREEN}active''${NC}" ;;
        off) echo -e "Firmware Secure Boot:  ''${YELLOW}inactive''${NC}" ;;
        *) echo -e "Firmware Secure Boot:  ''${YELLOW}unknown, the SecureBoot variable could not be read''${NC}" ;;
      esac

      case "$status_keys" in
        setup) echo "Firmware keys:         setup mode, no platform key, keys can be enrolled" ;;
        user) echo "Firmware keys:         user mode, a platform key is already enrolled" ;;
        *) echo "Firmware keys:         unknown, the SetupMode variable could not be read" ;;
      esac

      case "$status_declared" in
        enabled) echo -e "ModulixOS declaration: ''${GREEN}mx.bootloader.secureBoot.enable = true''${NC}" ;;
        disabled) echo "ModulixOS declaration: mx.bootloader.secureBoot.enable not set" ;;
        *) echo -e "ModulixOS declaration: ''${YELLOW}unknown, $boot_nix could not be evaluated''${NC}" ;;
      esac

      if [ "$status_declared" = enabled ] && [ "$status_firmware" = off ]; then
        echo -e "''${YELLOW}Keys are enrolled and the bootloader is signed, but Secure Boot is still off in the firmware.''${NC}"
        echo "Switch it on in the firmware setup menu to finish."
      elif [ "$status_declared" = disabled ] && [ "$status_keys" = setup ]; then
        echo "Run 'mx-sbctl --enable' to enrol a key set, sign the bootloader and rebuild."
      elif [ "$status_declared" = disabled ] && [ "$status_keys" = user ]; then
        echo "Enabling needs the firmware in setup mode: clear the Secure Boot keys from the firmware setup menu first."
      fi
    }

    if [ "$#" -gt 1 ]; then
      echo "mx-sbctl: too many arguments" >&2
      echo "usage: mx-sbctl [--enable|--disable]" >&2
      exit 2
    fi

    action=""

    case "''${1:-}" in
      -h|--help)
        echo "usage: mx-sbctl [--enable|--disable]"
        echo
        echo "Without an argument, print the current Secure Boot status: the firmware state"
        echo "read from the UEFI variables, and whether ModulixOS declares Secure Boot."
        echo
        echo "  --enable     declare mx.bootloader.secureBoot.enable, generate and enrol a"
        echo "               Modulix key set, sign the bootloader and rebuild the system"
        echo "  --disable    remove that declaration and rebuild the system with an"
        echo "               unsigned bootloader"
        echo "  -h, --help   show this help"
        echo
        echo "Enabling requires the firmware to be in setup mode, with no platform key:"
        echo "clear the Secure Boot keys from the firmware setup menu to get there."
        echo "Once enabled, Secure Boot still has to be switched on in the firmware"
        echo "setup menu, which the rebuild cannot do."
        echo
        echo "--enable and --disable require administrator authentication from an active"
        echo "local session, so they do not work over ssh and must not be run as root."
        echo "The rebuild can take several minutes, during which the command waits"
        echo "silently for the daemon reply. Reading the status needs no authentication."
        exit 0 ;;
      --enable) action=true ;;
      --disable) action=false ;;
      "")
        print_status
        exit 0 ;;
      *)
        echo "mx-sbctl: unexpected argument '$1'" >&2
        echo "usage: mx-sbctl [--enable|--disable]" >&2
        exit 2 ;;
    esac

    if [ "$action" = true ]; then
      if [ ! -d "$efi_dir" ]; then
        echo "mx-sbctl: this machine did not boot in UEFI mode, so it has no Secure Boot to enable" >&2
        exit 1
      fi
      if [ "$(firmware_keys)" = user ]; then
        echo "mx-sbctl: the firmware already has a platform key enrolled, so no new key set can be written" >&2
        echo "mx-sbctl: clear the Secure Boot keys from the firmware setup menu to put it back in setup mode, then try again" >&2
        exit 1
      fi
    fi

    if [ "$(${pkgs.coreutils}/bin/id -u)" -eq 0 ]; then
      echo "mx-sbctl: run as your own user, not as root" >&2
      echo "mx-sbctl: polkit authorizes the calling session, root has none" >&2
      exit 1
    fi

    if [ -z "''${DISPLAY:-}" ] && [ -z "''${WAYLAND_DISPLAY:-}" ]; then
      ${pkgs.polkit}/bin/pkttyagent --process $$ &
      agent=$!
      trap 'kill "$agent" 2>/dev/null || true' EXIT
    fi

    if [ "$action" = true ]; then
      echo -e "''${GREEN}Enabling secure boot, then rebuilding the system (this can take minutes)...''${NC}"
    else
      echo -e "''${GREEN}Disabling secure boot, then rebuilding the system (this can take minutes)...''${NC}"
    fi

    if ! reply=$(${busctl} --system --timeout=3600 --json=short \
          call org.modulix.Daemon /org/modulix/Daemon \
               org.modulix.Daemon SetSecureBoot b "$action" 2>&1); then
      echo -e "''${RED}mx-sbctl failed:''${NC} $reply" >&2
      case "$reply" in
        *"not authorized for action org.modulix.daemon.secureboot"*)
          echo "mx-sbctl: authentication refused, or this is not an active local session (ssh)" >&2 ;;
        *"already has a Platform Key enrolled"*)
          echo "mx-sbctl: clear the Secure Boot keys from the firmware setup menu to put it back in setup mode, then try again" >&2 ;;
        *"did not boot in UEFI mode"*)
          echo "mx-sbctl: this machine has no Secure Boot to enable" >&2 ;;
        *"daemon is shutting down"*)
          echo "mx-sbctl: the daemon is terminating, retry once it is back" >&2 ;;
        *"Unknown method"*|*"UnknownMethod"*)
          echo "mx-sbctl: the running modulix-daemon has no SetSecureBoot method, rebuild the system first" >&2 ;;
      esac
      exit 1
    fi

    echo -e "''${GREEN}$(printf '%s' "$reply" | ${jq} -r '.data[0]')''${NC}"

    if [ "$action" = true ]; then
      echo "A Modulix key set was generated, enrolled into the firmware, and the bootloader was signed."
      echo -e "''${YELLOW}Secure Boot is still off until you switch it on in the firmware setup menu.''${NC}"
    else
      echo "The Secure Boot declaration was removed, so the new bootloader is not signed."
      if [ "$(firmware_secure_boot)" = on ]; then
        echo -e "''${RED}Secure Boot is still active in the firmware. Switch it off in the firmware setup menu before rebooting, or the unsigned bootloader will be refused.''${NC}"
      else
        echo "The enrolled keys stay in the firmware; clear them from the setup menu to go back to setup mode."
      fi
    fi

    if boot=$(${busctl} --system --json=short \
          call org.modulix.Daemon /org/modulix/Daemon \
               org.modulix.Store1 RebootRequired 2>/dev/null); then
      if [ "$(printf '%s' "$boot" | ${jq} -r '.data[0]')" = "true" ]; then
        echo -e "''${YELLOW}Reboot required to finish applying the new boot configuration''${NC}"
      fi
    fi
  '';

  completion = dest: text: pkgs.writeTextFile {
    name = "mx-sbctl-completion";
    inherit text;
    destination = dest;
  };
in
pkgs.symlinkJoin {
  name = "mx-sbctl";
  paths = [
    script

    (completion "/share/bash-completion/completions/mx-sbctl" ''
      _mx_sbctl() {
        local cur="''${COMP_WORDS[COMP_CWORD]}"
        COMPREPLY=( $(compgen -W "--enable --disable --help" -- "$cur") )
      }
      complete -F _mx_sbctl mx-sbctl
    '')

    (completion "/share/zsh/site-functions/_mx-sbctl" ''
      #compdef mx-sbctl
      _arguments \
        '(- *)--enable[enable secure boot and rebuild]' \
        '(- *)--disable[disable secure boot and rebuild]' \
        '(- *)'{-h,--help}'[show help]'
    '')

    (completion "/share/fish/vendor_completions.d/mx-sbctl.fish" ''
      complete -c mx-sbctl -f
      complete -c mx-sbctl -l enable -d 'Enable secure boot and rebuild'
      complete -c mx-sbctl -l disable -d 'Disable secure boot and rebuild'
      complete -c mx-sbctl -s h -l help -d 'Show help'
    '')
  ];

  meta.mainProgram = "mx-sbctl";
}
