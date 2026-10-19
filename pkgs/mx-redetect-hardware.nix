{ pkgs ? import <nixpkgs> {} }:

let
  busctl = "${pkgs.systemd}/bin/busctl";
  jq = "${pkgs.jq}/bin/jq";

  script = pkgs.writeShellScriptBin "mx-redetect-hardware" ''
    set -euo pipefail

    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'

    case "''${1:-}" in
      -h|--help)
        echo "usage: mx-redetect-hardware"
        echo
        echo "Re-detect the machine hardware, rewrite the mx.hardware.* options"
        echo "and rebuild the system with them."
        echo
        echo "Requires administrator authentication from an active local session."
        echo "The rebuild can take several minutes, during which the command waits"
        echo "silently for the daemon reply."
        exit 0 ;;
      "") ;;
      *)
        echo "mx-redetect-hardware: unexpected argument '$1'" >&2
        exit 2 ;;
    esac

    if [ "$(${pkgs.coreutils}/bin/id -u)" -eq 0 ]; then
      echo "mx-redetect-hardware: run as your own user, not as root" >&2
      echo "mx-redetect-hardware: polkit authorizes the calling session, root has none" >&2
      exit 1
    fi

    if [ -z "''${DISPLAY:-}" ] && [ -z "''${WAYLAND_DISPLAY:-}" ]; then
      ${pkgs.polkit}/bin/pkttyagent --process $$ &
      agent=$!
      trap 'kill "$agent" 2>/dev/null || true' EXIT
    fi

    echo -e "$GREEN Re-detecting hardware, then rebuilding the system (this can take minutes)...$NC"

    if ! reply=$(${busctl} --system --timeout=3600 --json=short \
          call org.modulix.Daemon /org/modulix/Daemon \
               org.modulix.Daemon UpdateHardware 2>&1); then
      echo -e "$RED mx-redetect-hardware failed:$NC $reply" >&2
      case "$reply" in
        *"not authorized for action org.modulix.daemon.hardware"*)
          echo "mx-redetect-hardware: authentication refused, or this is not an active local session (ssh)" >&2 ;;
        *"daemon is shutting down"*)
          echo "mx-redetect-hardware: the daemon is terminating, retry once it is back" >&2 ;;
      esac
      exit 1
    fi

    echo -e "$GREEN $(printf '%s' "$reply" | ${jq} -r '.data[0]')$NC"

    if boot=$(${busctl} --system --json=short \
          call org.modulix.Daemon /org/modulix/Daemon \
               org.modulix.Store1 RebootRequired 2>/dev/null); then
      if [ "$(printf '%s' "$boot" | ${jq} -r '.data[0]')" = "true" ]; then
        echo -e "$YELLOW Reboot required: $(printf '%s' "$boot" | ${jq} -r '.data[1] | join(", ")')$NC"
      fi
    fi
  '';

  completion = dest: text: pkgs.writeTextFile {
    name = "mx-redetect-hardware-completion";
    inherit text;
    destination = dest;
  };
in
pkgs.symlinkJoin {
  name = "mx-redetect-hardware";
  paths = [
    script

    (completion "/share/bash-completion/completions/mx-redetect-hardware" ''
      _mx_redetect_hardware() {
        local cur="''${COMP_WORDS[COMP_CWORD]}"
        COMPREPLY=( $(compgen -W "--help" -- "$cur") )
      }
      complete -F _mx_redetect_hardware mx-redetect-hardware
    '')

    (completion "/share/zsh/site-functions/_mx-redetect-hardware" ''
      #compdef mx-redetect-hardware
      _arguments '(- *)'{-h,--help}'[show help]'
    '')

    (completion "/share/fish/vendor_completions.d/mx-redetect-hardware.fish" ''
      complete -c mx-redetect-hardware -f
      complete -c mx-redetect-hardware -s h -l help -d 'Show help'
    '')
  ];

  meta.mainProgram = "mx-redetect-hardware";
}
