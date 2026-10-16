{ pkgs ? import <nixpkgs> {} }:

pkgs.writeShellScriptBin "mx-clean-generations" ''
  set -euo pipefail
  [ "$(${pkgs.coreutils}/bin/id -u)" -eq 0 ] || exec sudo "$0" "$@"

  nix_env=${pkgs.nix}/bin/nix-env

  for profiles in /root/.local/state/nix/profiles /home/*/.local/state/nix/profiles; do
    [ -d "$profiles" ] || continue
    for p in "$profiles"/*; do
      case "$p" in *-link) continue ;; esac
      [ -L "$p" ] || continue
      $nix_env --profile "$p" --delete-generations old
    done
  done

  $nix_env --profile /nix/var/nix/profiles/system --delete-generations old
  ${pkgs.nix}/bin/nix-collect-garbage -d
  /nix/var/nix/profiles/system/bin/switch-to-configuration boot
''
