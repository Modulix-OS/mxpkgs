{ pkgs ? import <nixpkgs> {} }:

let
  script = pkgs.writeShellScriptBin "mx-list-generations" ''
    set -euo pipefail

    all=0
    for arg in "$@"; do
      case "$arg" in
        --all-profiles) all=1 ;;
        -h|--help)
          echo "usage: mx-list-generations [--all-profiles]"
          echo "  --all-profiles  liste aussi les profils de tous les users"
          exit 0 ;;
        *) echo "option inconnue: $arg" >&2; exit 2 ;;
      esac
    done

    [ "$(${pkgs.coreutils}/bin/id -u)" -eq 0 ] || exec sudo "$0" "$@"

    nix_env=${pkgs.nix}/bin/nix-env

    echo "== system =="
    $nix_env --profile /nix/var/nix/profiles/system --list-generations

    [ "$all" -eq 1 ] || exit 0

    for profiles in /nix/var/nix/profiles/per-user/* /root/.local/state/nix/profiles /home/*/.local/state/nix/profiles; do
      [ -d "$profiles" ] || continue
      for p in "$profiles"/*; do
        case "$p" in *-link) continue ;; esac
        [ -L "$p" ] || continue
        echo
        echo "== $p =="
        $nix_env --profile "$p" --list-generations
      done
    done
  '';

  completion = dest: text: pkgs.writeTextFile {
    name = "mx-list-generations-completion";
    inherit text;
    destination = dest;
  };
in
pkgs.symlinkJoin {
  name = "mx-list-generations";
  paths = [
    script

    (completion "/share/bash-completion/completions/mx-list-generations" ''
      _mx_list_generations() {
        COMPREPLY=( $(compgen -W "--all-profiles --help" -- "''${COMP_WORDS[COMP_CWORD]}") )
      }
      complete -F _mx_list_generations mx-list-generations
    '')

    (completion "/share/zsh/site-functions/_mx-list-generations" ''
      #compdef mx-list-generations
      _arguments \
        '--all-profiles[lister les profils de tous les users]' \
        '(- *)'{-h,--help}'[afficher l aide]'
    '')

    (completion "/share/fish/vendor_completions.d/mx-list-generations.fish" ''
      complete -c mx-list-generations -l all-profiles -d 'Lister les profils de tous les users'
      complete -c mx-list-generations -s h -l help -d 'Afficher aide'
    '')
  ];
}
