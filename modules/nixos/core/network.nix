{ config, lib, pkgs, ... }:

let
  cfg = config.mx.core.network;
  normalUsers = import ../../../lib/normal-user.nix { inherit config; };
in
{
  options.mx.core.network = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable networking fonctionnality";
    };
    security-mode = lib.mkEnableOption "Enable advanced networking security settings";
    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = normalUsers;
      description = "Users for whom arduino device permissions should be enabled.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        networking.networkmanager.enable = lib.mkDefault true;
        networking.firewall.enable = lib.mkForce true;

        users.users = builtins.listToAttrs (map (user: {
          name = user;
          value.extraGroups = [ "networkmanager" ];
        }) cfg.users);
      }
      (
        lib.mkIf cfg.security-mode {
          networking.networkmanager = {
            settings = {
              main = {
                hostname-mode = lib.mkForce "none";
              };

              connection = {
                "ipv4.dhcp-send-hostname" = lib.mkForce false;
                "ipv6.dhcp-send-hostname" = lib.mkForce false;
              };
            };
            wifi = {
              macAddress = "random";
              scanRandMacAddress = true;
            };
            ethernet = {
              macAddress = "random";
            };
          };
          environment.etc."machine-info".text = "";

          # Hostname anonyme pour mDNS/LLMNR
          services.resolved.extraConfig = ''
            MulticastDNS=no
            LLMNR=no
          '';

          services.avahi.enable = lib.mkForce false;
        }
      )
    ]
  );
}
