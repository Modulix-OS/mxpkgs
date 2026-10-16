{ pkgs ? import <nixpkgs> {} }:

pkgs.writeShellScriptBin "mx-clean" ''
  sudo ${pkgs.nix}/bin/nix-collect-garbage
''
