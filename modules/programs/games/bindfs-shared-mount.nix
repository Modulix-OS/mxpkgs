{ config, pkgs, lib, ... }:
let
  cfg = config.mx.programs.games;
  gamersGid = toString config.users.groups.gamers.gid;
  gamersMembers = config.users.groups.gamers.members;

  shared_dirs_conf = lib.types.submodule {
    options = {
      dir_name = lib.mkOption {
        type = lib.types.str;
        description = "Folder name";
      };
      real_path = lib.mkOption {
        type = lib.types.str;
        description = "Real path in filesystem";
      };
    };
  };
in
{
  options.mx.programs.games = {
    shared_steam_dir = lib.mkOption {
      type = lib.types.listOf shared_dirs_conf;
      default = [ ];
      description = ''
        List of all shared games folder between all gamers users
      '';
    };
  };

  config = lib.mkIf (cfg.enable && cfg.shared_steam_dir != [ ]) {
    environment.systemPackages = [ pkgs.bindfs ];

    systemd.tmpfiles.rules =
    let
      acl = lib.concatStringsSep "," [
        "user::rwX"
        "group::rwX"
        "group:gamers:rwX"
        "mask::rwX"
        "other::---"
        "default:user::rwx"
        "default:group::rwx"
        "default:group:gamers:rwx"
        "default:mask::rwx"
        "default:other::---"
      ];
      mkRules = owner: p: [
        "d ${p} 2770 ${owner} gamers -"
        "a+ ${p} - - - - ${acl}"
      ];
    in
    lib.concatMap (mkRules "root") cfg.game_lib_dirs
    ++ map (entry: "d ${entry.real_path} 0700 root root -") cfg.shared_steam_dir;

    systemd.services = lib.mkMerge (lib.flatten (map (user:
      let
        home = config.users.users.${user}.home;
      in map (entry:
        let
          target = "${home}/${entry.dir_name}";
        in {
          "mx-steam-shared-common-${user}-${entry.dir_name}" = {
            description = "Bindfs mount of shared Steam common dir ${entry.dir_name} for ${user}, root:gamers preserved on disk";
            after = [ "local-fs.target" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              Type = "simple";
              ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${target}";
              ExecStart = ''
                ${pkgs.bindfs}/bin/bindfs \
                  --map=root/${user} \
                  --create-for-user=0 --create-for-group=${gamersGid} \
                  --enable-lock-forwarding \
                  -o allow_other,x-gvfs-hide \
                  -o attr_timeout=300,entry_timeout=300,negative_timeout=300 \
                  -o kernel_cache \
                  --multithreaded \
                  -f \
                  ${entry.real_path} \
                  ${target}
              '';
              ExecStop = "${pkgs.fuse}/bin/fusermount -u ${target}";
              Restart = "on-failure";
            };
          };
        }
      ) cfg.shared_steam_dir
    ) gamersMembers));
  };
}
