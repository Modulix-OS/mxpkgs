{ lib, ... }:

{
    nix.settings.auto-optimise-store = true;
    nix.gc = {
        automatic = lib.mkMxDefault true;
        dates = lib.mkMxDefault "weekly";
        options = lib.mkMxDefault "--delete-older-than 14d";
    };
    services.fwupd.enable = true;
}
