{ pkgs ? import <nixpkgs> {} }:

let
  script = pkgs.writeShellScriptBin "mx-switch-generation" ''
    set -euo pipefail

    profile=/nix/var/nix/profiles/system

    case "''${1:-}" in
      -h|--help)
        echo "usage: mx-switch-generation <number>"
        exit 0 ;;
      ""|*[!0-9]*)
        echo "usage: mx-switch-generation <number>" >&2
        exit 2 ;;
    esac
    gen="$1"

    target="$profile-$gen-link"
    [ -e "$target" ] || { echo "generation $gen not found" >&2; exit 1; }

    [ "$(${pkgs.coreutils}/bin/id -u)" -eq 0 ] || exec sudo "$0" "$@"

    current="$(${pkgs.coreutils}/bin/readlink -f /run/current-system)"
    if [ "$current" = "$(${pkgs.coreutils}/bin/readlink -f "$target")" ]; then
      echo "generation $gen is already active"
      exit 0
    fi

    ${pkgs.nix}/bin/nix --extra-experimental-features nix-command \
      store diff-closures /run/current-system "$target"

    printf 'Switch to generation %s? [y/N] ' "$gen"
    read -r answer || answer=""
    case "$answer" in
      y|Y|yes|YES) ;;
      *) echo "aborted"; exit 1 ;;
    esac

    ${pkgs.nix}/bin/nix-env --profile "$profile" --switch-generation "$gen"
    "$profile/bin/switch-to-configuration" switch
  '';

  completion = dest: text: pkgs.writeTextFile {
    name = "mx-switch-generation-completion";
    inherit text;
    destination = dest;
  };
in
pkgs.symlinkJoin {
  name = "mx-switch-generation";
  paths = [
    script

    (completion "/share/bash-completion/completions/mx-switch-generation" ''
      _mx_switch_generation() {
        local cur="''${COMP_WORDS[COMP_CWORD]}"
        COMPREPLY=( $(compgen -W "--help $(ls /nix/var/nix/profiles | sed -n 's/^system-\([0-9]*\)-link$/\1/p')" -- "$cur") )
      }
      complete -F _mx_switch_generation mx-switch-generation
    '')

    (completion "/share/zsh/site-functions/_mx-switch-generation" ''
      #compdef mx-switch-generation
      _mx_gens() {
        local -a gens
        gens=($(ls /nix/var/nix/profiles | sed -n 's/^system-\([0-9]*\)-link$/\1/p'))
        _describe 'generation' gens
      }
      _arguments \
        '(- *)'{-h,--help}'[show help]' \
        '1:generation:_mx_gens'
    '')

    (completion "/share/fish/vendor_completions.d/mx-switch-generation.fish" ''
      complete -c mx-switch-generation -f
      complete -c mx-switch-generation -s h -l help -d 'Show help'
      complete -c mx-switch-generation -a "(ls /nix/var/nix/profiles | sed -n 's/^system-\([0-9]*\)-link\$/\1/p')" -d 'Generation'
    '')
  ];
}
