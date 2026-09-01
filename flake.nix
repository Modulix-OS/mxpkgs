{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
        url = "github:nix-community/home-manager/release-26.05";
        inputs.nixpkgs.follows = "nixpkgs";
    };
    firefox-addons = {
        url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
        inputs.nixpkgs.follows = "nixpkgs";
    };
    coe33 = {
      url = "github:qhorgues/CO-E33-Save-Editor";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Rust crate providing `mx-init`, the ModulixOS configuration generator.
    modulix-core-utils = {
      url = "github:Modulix-OS/modulix-core-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, coe33, ... }@inputs:
  let
    systems = [ "x86_64-linux" "aarch64-linux" "i686-linux" "x86_64-darwin" "aarch64-darwin" ];
    forAllSystems = nixpkgs.lib.genAttrs systems;

    nixpkgsConfig = {
      allowUnfree = true;
    };

    make-system = {
        system ? "x86_64-linux",
        modules ? [],
        specialArgs ? {},
      }:
      let
        pkgs-unstable = import nixpkgs-unstable {
          system = system;
          config = nixpkgsConfig;
        };
        defaults = {
          inherit self pkgs-unstable inputs;
        };
      in nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = defaults // specialArgs;
        modules = [
          inputs.home-manager.nixosModules.default
          ./modulixos
          ./modules
        ] ++ modules;
      };
  in
  {
    lib.modulixosSystem = make-system;
    nixosModules = {
      modulix-os =
        { ... }: {
          imports = [ ./modulixos ./modules ];
          _module.args = {
            inputs = inputs;
          };
        };
      home-manager = inputs.home-manager.nixosModules.default;
    };

    packages = forAllSystems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        coe33 = coe33.packages.${system}.default;
        clean-dir = import ./pkgs/clean-dir.nix { inherit pkgs; };
        lsfg-vk = pkgs.callPackage ./pkgs/lsfg-vk.nix {};
        nix-clean = import ./pkgs/nix-clean.nix { inherit pkgs; };
        nix-latest-update = import ./pkgs/nix-latest-update.nix { inherit pkgs; };
        kiwix = pkgs.callPackage ./pkgs/kiwix.nix { inherit pkgs; };
        modulix-logo = pkgs.callPackage ./pkgs/modulix-logo.nix { };
      } // nixpkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
        # ModulixOS configuration generator (Linux only).
        mx-init = inputs.modulix-core-utils.packages.${system}.mx-init;
      }
    );
  };
}
