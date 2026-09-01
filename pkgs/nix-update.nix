{ pkgs ? import <nixpkgs> {}, nix-latest-update, flake_path, flake_config }:

pkgs.writeShellScriptBin "nix-update" ''
    cd "${flake_path}" || exit 1

    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m' # No Color

    if ! ${pkgs.git}/bin/git rev-parse --git-dir > /dev/null 2>&1; then
        echo -e "$RED Error: This directory is not a git repository $NC"
        exit 1
    fi

    CURRENT_COMMIT=$(${pkgs.git}/bin/git rev-parse HEAD)

    PULL_OUTPUT=$(LANG=C ${pkgs.git}/bin/git pull 2>&1)
    PULL_EXIT_CODE=$?
    if echo "$PULL_OUTPUT" | grep -qi "conflict"; then
        echo -e "$RED Conflic detected in pull $NC"
        echo -e "$YELLOW Cancel pull $NC"

        ${pkgs.git}/bin/git merge --abort 2>&1

        if [ "$(${pkgs.git}/bin/git rev-parse HEAD)" = "$CURRENT_COMMIT" ]; then
            echo -e "$GREEN Pull aborted successfully. Repository restored to previous state.$NC"
        else
            echo -e "$RED Warning: Repository might not be in the expected state. $NC"
        fi
        exit 2
    fi

    if echo "$PULL_OUTPUT" | grep -qi "Already up to date\|Already up-to-date\|Déjà à jour"; then
        echo -e "$GREEN OS already up to date.$NC"
        exit 0
    fi

    if [ $PULL_EXIT_CODE -eq 0 ]; then
        echo -e "$GREEN Starting update... $NC"

        sudo ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --flake "${flake_path}#${flake_config}"
        COMMAND_EXIT_CODE=$?

        if [ $COMMAND_EXIT_CODE -eq 0 ]; then
            echo -e "$GREEN Update finish successfully!$NC"
            ${nix-latest-update}/bin/nix-latest-update
        else
            echo -e "$RED Update failed$NC"
            exit $COMMAND_EXIT_CODE
        fi
    else
        exit $PULL_EXIT_CODE
    fi
''
