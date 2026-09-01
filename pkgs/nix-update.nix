{ pkgs ? import <nixpkgs> {}, nix-latest-update, flake_path, flake_config }:

pkgs.writeShellScriptBin "nix-update" ''
    cd "${flake_path}" || exit 1

    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m' # No Color

    LOCK_BACKUP=$(${pkgs.coreutils}/bin/mktemp)
    trap '${pkgs.coreutils}/bin/rm -f "$LOCK_BACKUP"' EXIT

    hash_lock() {
        if [ -f flake.lock ]; then
            ${pkgs.coreutils}/bin/sha256sum flake.lock | ${pkgs.coreutils}/bin/cut -d' ' -f1
        fi
    }

    restore_lock() {
        if [ -s "$LOCK_BACKUP" ]; then
            ${pkgs.coreutils}/bin/cp "$LOCK_BACKUP" flake.lock
            echo -e "$YELLOW flake.lock restored $NC"
        fi
    }

    if [ -f flake.lock ]; then
        ${pkgs.coreutils}/bin/cp flake.lock "$LOCK_BACKUP"
    fi

    OLD_HASH=$(hash_lock)

    ${pkgs.nix}/bin/nix flake update --flake "${flake_path}"
    UPDATE_EXIT_CODE=$?

    if [ $UPDATE_EXIT_CODE -ne 0 ]; then
        echo -e "$RED Flake update failed $NC"
        restore_lock
        exit $UPDATE_EXIT_CODE
    fi

    NEW_HASH=$(hash_lock)

    if [ "$OLD_HASH" = "$NEW_HASH" ]; then
        echo -e "$GREEN OS already up to date.$NC"
        exit 0
    fi

    echo -e "$GREEN Starting update... $NC"

    sudo ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --flake "${flake_path}#${flake_config}"
    COMMAND_EXIT_CODE=$?

    if [ $COMMAND_EXIT_CODE -eq 0 ]; then
        echo -e "$GREEN Update finish successfully!$NC"
        ${nix-latest-update}/bin/nix-latest-update
    else
        echo -e "$RED Update failed$NC"
        restore_lock
        exit $COMMAND_EXIT_CODE
    fi
''
