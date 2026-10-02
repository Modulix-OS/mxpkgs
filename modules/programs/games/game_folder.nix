{ config, lib, ... }:
let
  cfg = config.mx.programs.games;

  user_dirs_conf = lib.types.submodule {
    options = {
      user = lib.mkOption {
        type = lib.types.str;
        description = "Owner of the folder";
      };
      path = lib.mkOption {
        type = lib.types.str;
        description = "Real path in filesystem";
      };
    };
  };
in
{
  options.mx.programs.games = {
    game_user_lib_dir = lib.mkOption {
      type = lib.types.listOf user_dirs_conf;
      default = [ ];
      description = ''
        List of games folder dedicated to a single user
      '';
    };
  };

  config = lib.mkIf (cfg.enable && cfg.game_user_lib_dir != [ ]) {
    systemd.tmpfiles.rules = map (
      entry: "d ${entry.path} 0755 ${entry.user} users -"
    ) cfg.game_user_lib_dir;
  };
}
