{ config, lib, pkgs, ... }:

let
  cfg = config.mx.core.network;
  normalUsers = import ../lib/normal-user.nix { inherit config; };
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
        networking.firewall.enable = lib.mkForce true;
      }
      (lib.mkIf (!config.mx.mode.server.enable) {
        networking.networkmanager.enable = lib.mkMxDefault true;
        users.groups.networkmanager.members = cfg.users;
      })
      (lib.mkIf cfg.security-mode {
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
            macAddress = lib.mkMxDefault "random";
            scanRandMacAddress = lib.mkMxDefault true;
          };
          ethernet = {
            macAddress = lib.mkMxDefault "random";
          };
        };
        environment.etc."machine-info".text = "";

        services.resolved.settings.Resolve = {
          MulticastDNS = lib.mkMxDefault "no";
          LLMNR = lib.mkMxDefault "no";
        };

        services.avahi.publish = {
          enable = lib.mkForce false;
          addresses = lib.mkForce false;
          domain = lib.mkForce false;
          hinfo = lib.mkForce false;
          userServices = lib.mkForce false;
          workstation = lib.mkForce false;
        };
      })
    ]
  );
}
