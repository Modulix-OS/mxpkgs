{ config, lib, ... }:

let
  cfg = config.mx.hardware;
in
{
  config = lib.mkIf (!config.mx.mode.server.enable && cfg.has_fingerprint) {
    services.fprintd.enable = true;
  };
}
