{ config, lib, ... }:
let
  cfg = config.mx.cache.modulix;
in
{
  options.mx.cache.modulix = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to pull Modulix packages (mx-daemon, gnome-software-modulix)
        from the Modulix Attic binary cache instead of building them locally.
      '';
    };
  };

  config = {
    nix.settings.substituters = lib.optionals cfg.enable [
      "https://cache.modulixos.org:8443/modulix"
    ];
    nix.settings.trusted-public-keys = lib.optionals cfg.enable [
      "modulix:4Iz1f0Pvc7i92PYpToUlgiya/Qyg9YY1mS86xC+Rbf4="
    ];
  };
}
