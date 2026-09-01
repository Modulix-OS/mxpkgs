{ config, lib, ... }:
let
  cfg = config.mx.hardware.ssd;
in
{
  options.mx.hardware.ssd = {
    lists = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "List of ssd in system";
    };
  };

  config = {
    hardware.block = {
      defaultScheduler = lib.mkMxDefault "kyber";
      defaultSchedulerRotational = lib.mkMxDefault "bfq";
    };

    fileSystems = builtins.listToAttrs (map (disk: {
      name = disk;
      value.options = [ "noatime" "nodiratime" "discard" "defaults" "commit=120" ];
    }) cfg.lists);
  };
}
