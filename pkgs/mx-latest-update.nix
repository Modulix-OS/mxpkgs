{ pkgs ? import <nixpkgs> {} }:

pkgs.writeShellScriptBin "mx-latest-update" ''
  ${pkgs.nix}/bin/nix store diff-closures $(${pkgs.coreutils}/bin/ls -d1v /nix/var/nix/profiles/system-*-link | ${pkgs.coreutils}/bin/tail -n 2)
''
