{
  description = "Modulix-OS test VMs (gnome / plasma / cli desktop options)";

  # Pin everything through the parent flake so versions stay in lockstep and
  # no inputs are re-fetched (uses the parent's locked revisions).
  inputs = {
    mx.url = "path:..";
    nixpkgs.follows = "mx/nixpkgs";
    nixpkgs-unstable.follows = "mx/nixpkgs-unstable";
    home-manager.follows = "mx/home-manager";
    nix-cachyos-kernel.follows = "mx/nix-cachyos-kernel";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };

      mkVm = desktop: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit self inputs pkgs-unstable; };
        modules = [
          home-manager.nixosModules.default
          ../modulixos
          ../modules
          ./vm-common.nix
          { mx.desktop = desktop; }
        ];
      };
      gpuTests = import ./gpu-eval.nix {
        inherit (nixpkgs) lib;
        inherit pkgs;
        baseSystem = self.nixosConfigurations.test-cli;
      };
    in
    {
      nixosConfigurations = {
        test-gnome = mkVm "gnome";
        test-plasma = mkVm "plasma";
        test-cli = mkVm "cli";
      };

      # GPU module eval tests. `nix build .#checks.x86_64-linux.gpu` builds only this
      # check (does not build the VMs), so it stays cheap and isolated.
      checks.${system}.gpu = gpuTests.check;

      # Machine-readable results: `nix eval .#gpuEval.x86_64-linux --json | jq`
      gpuEval.${system} = gpuTests.results;
    };
}
