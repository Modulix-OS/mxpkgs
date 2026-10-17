{ config, lib, ... }:
let
  cfg = config.mx.cache.modulix;
  configured = cfg.enable && cfg.publicKey != "";
in
{
  options.mx.cache.modulix = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to pull Modulix packages (mx-daemon, gnome-software-modulix)
        from the Modulix Attic binary cache instead of building them locally.
        Ignored while `publicKey` is empty.
      '';
    };

    url = lib.mkOption {
      type = lib.types.str;
      default = "https://cache.modulixos.org:16443/modulix";
      description = "Substituter URL of the Modulix Attic cache.";
    };

    publicKey = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "modulix:eUlb0qfPWDQsmZjhxhDjRPn3xJqLRMFTHMOxHxrWgQQ=";
      description = ''
        Signing key the cache signs its narinfos with, as reported by
        `attic cache info modulix`. An empty value disables the substituter:
        an unsigned cache would be refused anyway.
      '';
    };
  };

  config = {
    warnings = lib.optional (cfg.enable && cfg.publicKey == "")
      "mx.cache.modulix is enabled but mx.cache.modulix.publicKey is empty; the Modulix binary cache is not used.";

    nix.settings.substituters = lib.optionals configured [ cfg.url ];
    nix.settings.trusted-public-keys = lib.optionals configured [ cfg.publicKey ];
  };
}
