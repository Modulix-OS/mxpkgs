{ config, lib, ... }:
let
  cfg = config.mx.programs.games;

  shared_paths = cfg.game_lib_dirs ++ map (entry: entry.real_path) cfg.game_shared_lib_dir;
  user_paths = map (entry: entry.path) cfg.game_user_lib_dir;

  conflicts = lib.intersectLists shared_paths user_paths;
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = conflicts == [ ];
        message = ''
          mx.programs.games.game_user_lib_dir declares ${lib.concatStringsSep ", " conflicts} which is also a shared games folder
          (mx.programs.games.game_lib_dirs or mx.programs.games.game_shared_lib_dir).
          A games folder cannot be both shared between gamers and private to a single user.
        '';
      }
    ];
  };
}
