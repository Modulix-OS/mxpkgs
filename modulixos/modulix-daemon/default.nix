{ config, lib, inputs, ... }:

{
  imports = [ inputs.modulix-daemon.nixosModules.mx-daemon ];

  config = lib.mkMerge [
    {
      mx.services.modulix-daemon = {
        enable = lib.mkDefault (!config.mx.mode.server.enable);

        moduleIndexFiles = {
          "index.json" = ../../modules/index.json;
          "index.fr.json" = ../../modules/index.fr.json;
        };
      };
    }

    (lib.mkIf config.mx.services.modulix-daemon.enable {
      nix.registry.nixpkgs.flake = inputs.nixpkgs;
      nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
    })
  ];
}
