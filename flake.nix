{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
        url = "github:nix-community/home-manager/release-26.05";
        inputs.nixpkgs.follows = "nixpkgs";
    };
    firefox-addons = {
        url = "git+https://gitlab.com/rycee/nur-expressions.git?dir=pkgs/firefox-addons";
        inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";

    modulix-daemon.url = "github:Modulix-OS/modulix-daemon/v1.1.0";

    gnome-software-plugin.url = "github:Modulix-OS/gnome-software-plugin/v1.0.1";

    modulix-core-utils = {
      url = "github:Modulix-OS/modulix-core-utils/v1.1.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, ... }@inputs:
  let
    modulixRelease = builtins.fromJSON (builtins.readFile ./release.json);

    systems = [ "x86_64-linux" "aarch64-linux" "i686-linux" "x86_64-darwin" "aarch64-darwin" ];
    forAllSystems = nixpkgs.lib.genAttrs systems;

    gnomeSystems = [ "x86_64-linux" "aarch64-linux" ];
    forGnomeSystems = nixpkgs.lib.genAttrs gnomeSystems;

    nixpkgsConfig = {
      allowUnfree = true;
    };

    brandingModule = { mx.branding = modulixRelease; };

    extendLib = base: base.extend (final: prev:
      import ./lib/mx-priority.nix { lib = prev; }
      // import ./lib/mx-gpuStack.nix { lib = prev; });
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
          brandingModule
        ] ++ modules;
      };
  in
  {
    lib = {
      modulixosSystem = make-system;
      inherit extendLib;
      inherit (mxLib) mkMxDefault mxDefaultPriority;
      inherit modulixRelease;

      mkGameConfigSwitcher = { pkgs, ... } @ args:
        pkgs.callPackage ./lib/game-settings-switcher.nix args;

      igpu-launch = { pkgs, igpuId, igpuNumber }:
        pkgs.callPackage ./lib/igpu-launch.nix { inherit igpuId igpuNumber; };

      mkMxUpdate = { pkgs, flake_path, flake_config }:
        import ./pkgs/mx-update.nix {
          inherit pkgs flake_path flake_config;
          mx-diff-update = import ./pkgs/mx-diff-update.nix { inherit pkgs; };
        };
    };

    nixosModules = {
      modulix-os =
        { ... }: {
          imports = [ ./modulixos ./modules brandingModule ];
          _module.args = {
            inputs = inputs;
          };
        };
      home-manager = inputs.home-manager.nixosModules.default;
      attic-cache = import ./infra/attic-cache.nix;
    };

    packages = forAllSystems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        clean-dir = import ./pkgs/clean-dir.nix { inherit pkgs; };
        lsfg-vk = pkgs.callPackage ./pkgs/lsfg-vk.nix {};
        mx-clean = import ./pkgs/mx-clean.nix { inherit pkgs; };
        mx-clean-generations = import ./pkgs/mx-clean-generations.nix { inherit pkgs; };
        mx-list-generations = import ./pkgs/mx-list-generations.nix { inherit pkgs; };
        mx-switch-generation = import ./pkgs/mx-switch-generation.nix { inherit pkgs; };
        mx-diff-update = import ./pkgs/mx-diff-update.nix { inherit pkgs; };
        mx-redetect-hardware = import ./pkgs/mx-redetect-hardware.nix { inherit pkgs; };
        mx-mp4-to-mov = import ./pkgs/mx-mp4-to-mov.nix { inherit pkgs; };
        mx-ubuntu-box = import ./pkgs/mx-ubuntu-box.nix { inherit pkgs; };
        mx-ue5 = import ./pkgs/mx-ue5.nix { inherit pkgs; };
        modulix-logo = pkgs.callPackage ./pkgs/modulix-logo.nix { };
        modulix-icon = pkgs.callPackage ./pkgs/modulix-icon.nix { };
        modulix-plymouth-theme = pkgs.callPackage ./pkgs/modulix-plymouth-theme.nix {
          logo = ./assets/modulix-logo.png;
        };
        gnome-rounded-blur = pkgs.callPackage ./pkgs/gnome-rounded-blur.nix {};
        gnome-shell-extension-hanabi = pkgs.callPackage ./pkgs/hanabi.nix {};
        mx-firefox-search-provider = pkgs.callPackage ./pkgs/mx-firefox-search-provider.nix { };
        patch-runner = import ./pkgs/patch-runner.nix { inherit pkgs; };
      }
    );

    checks = forGnomeSystems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        gnome-shell-app-folder-order-patch =
          pkgs.runCommand "gnome-shell-app-folder-order-patch"
            {
              src = pkgs.gnome-shell.src;
              nativeBuildInputs = [ pkgs.gnupatch ];
            }
            ''
              tar xf "$src" --wildcards --strip-components=1 '*/js/ui/appDisplay.js'
              patch -p1 < ${./modulixos/desktop/gnome/patches/0001-appDisplay-refresh-the-app-info-list-before-folders.patch}
              grep -q '_refreshAppInfoList();' js/ui/appDisplay.js
              touch "$out"
            '';
      }
    );
  };
}
