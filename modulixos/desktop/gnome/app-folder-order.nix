{ config, lib, ... }:

{
  options = {
    mx.gnome.app-folder-order = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "patch GNOME Shell so an application installed later is filed into its app-grid folder on the first redisplay instead of the next one";
    };
  };

  config = lib.mkIf (config.mx.desktop == "gnome" && config.mx.gnome.app-folder-order) {
    nixpkgs.overlays = [ (import ./app-folder-order-overlay.nix) ];
  };
}
