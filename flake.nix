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
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, ... }@inputs:
  let
    systems = [ "x86_64-linux" "aarch64-linux" "i686-linux" "x86_64-darwin" "aarch64-darwin" ];
    forAllSystems = nixpkgs.lib.genAttrs systems;

    nixpkgsConfig = {
      allowUnfree = true;
    };

    extendLib = base: base.extend (final: prev: import ./lib/mx-lib.nix { lib = prev; });
    mxLib = extendLib nixpkgs.lib;

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
        lib = mxLib;
        specialArgs = defaults // specialArgs;
        modules = [
          inputs.home-manager.nixosModules.default
          ./modulixos
          ./modules
        ] ++ modules;
      };
  in
  {
    lib = {
      modulixosSystem = make-system;
      inherit extendLib;
      inherit (mxLib) mkMxDefault mxDefaultPriority;

      mkGameConfigSwitcher = { pkgs, ... } @ args:
        pkgs.callPackage ./lib/game-settings-switcher.nix args;

      igpu-launch = { pkgs, igpuId, igpuNumber }:
        pkgs.callPackage ./lib/igpu-launch.nix { inherit igpuId igpuNumber; };

      mkMxUpdate = { pkgs, flake_path, flake_config }:
        import ./pkgs/mx-update.nix {
          inherit pkgs flake_path flake_config;
          mx-latest-update = import ./pkgs/mx-latest-update.nix { inherit pkgs; };
        };

      mkMxCleanBoot = { pkgs, flake_path, flake_config }:
        import ./pkgs/mx-clean-boot.nix { inherit pkgs flake_path flake_config; };
    };

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
        clean-dir = import ./pkgs/clean-dir.nix { inherit pkgs; };
        lsfg-vk = pkgs.callPackage ./pkgs/lsfg-vk.nix {};
        mx-clean = import ./pkgs/mx-clean.nix { inherit pkgs; };
        mx-latest-update = import ./pkgs/mx-latest-update.nix { inherit pkgs; };
        modulix-logo = pkgs.callPackage ./pkgs/modulix-logo.nix { };
        modulix-icon = pkgs.callPackage ./pkgs/modulix-icon.nix { };
        gnome-rounded-blur = pkgs.callPackage ./pkgs/gnome-rounded-blur.nix {};
        gnomeExtensions.hanabi = pkgs.callPackage ./pkgs/hanabi.nix {};
      }
    );
  };
}
