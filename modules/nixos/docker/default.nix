{ config, lib, ... }:

let
  cfg = config.mx.services.docker;
  normalUsers = import ../../../lib/normal-user.nix { inherit config; };
in
{
  options.mx.services.docker = {
    enable = lib.mkEnableOption "Enable docker service";

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = normalUsers;
      description = "Users can run and setup docker";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker = {
      enable = true;
      rootless.enable = true;
    };

    users.users = builtins.listToAttrs (map (user: {
      name = user;
      value.extraGroups = [ "docker" ];
    }) cfg.users);
  };
}
