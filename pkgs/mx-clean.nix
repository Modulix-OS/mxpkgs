{ pkgs ? import <nixpkgs> {} }:

pkgs.writeShellScriptBin "mx-clean" ''
    ${pkgs.nix}/bin/nix-store --gc
    ${pkgs.nix}/bin/nix-collect-garbage -d
''
