{ pkgs ? import <nixpkgs> {}, flake_path, flake_config }:

pkgs.writeShellScriptBin "mx-clean-boot" ''
    ${pkgs.nix}/bin/nix flake update --flake "${flake_path}"
    sudo ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --flake "${flake_path}#${flake_config}"
    sudo ${pkgs.coreutils}/bin/rm -f /nix/var/nix/gcroots/auto/*
    sudo ${pkgs.nix}/bin/nix-store --gc
    sudo ${pkgs.nix}/bin/nix-collect-garbage -d
''
