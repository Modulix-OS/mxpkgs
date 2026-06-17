{ config, lib, pkgs, ... }:
let
  cfg = config.mx.programs.arduino;
  normalUsers = import ../../lib/normal-user.nix { inherit config; };
in {
  options.mx.programs.arduino = {
    enable = lib.mkEnableOption "Enable Arduino dev tools";
    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = normalUsers;
      description = "Users for whom arduino device permissions should be enabled.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.arduino-ide
      pkgs.arduino-language-server
      pkgs.arduino-cli
    ];
    services.udev.packages = [ pkgs.arduino-ide ];
    users.users = builtins.listToAttrs (map (user: {
      name = user;
      value.extraGroups = [ "dialout" "uucp" ];
    }) cfg.users);
  };
}
