{ lib, config, ... }:
let
  cfg = config.mx.core.networking.dnsmasq;
in
{
  options.mx.core.networking.dnsmasq = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the local dnsmasq DNS cache";
    };
  };
  config = lib.mkIf cfg.enable {
    services.dnsmasq = {
      enable = true;
      settings = {
        listen-address = lib.mkMxDefault [
          "127.0.0.1"
          "::1"
        ];
        bind-dynamic = lib.mkMxDefault true;
        cache-size = lib.mkMxDefault 1000;
        no-resolv = lib.mkMxDefault false;
      };
    };
  };
}
