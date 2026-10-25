{ lib, pkgs, config }:

let
  stateDir = "/var/lib/mx-flatpak/owned";

  mkFlatpakConfig =
    { name
    , appId
    , enable
    , remote ? "flathub"
    , branch ? null
    }:
    let
      ref = lib.escapeShellArg appId;
      marker = lib.escapeShellArg "${stateDir}/${appId}";
      installArgs = lib.escapeShellArgs ([ remote appId ] ++ lib.optional (branch != null) branch);

      installUnit = "mx-flatpak-install-${name}";
      removeUnit = "mx-flatpak-remove-${name}";
    in
    lib.mkMerge [
      (lib.mkIf enable {
        mx.services.flatpak.enable = lib.mkMxDefault true;

        systemd.services.${installUnit} = {
          description = "Install the ${appId} Flatpak";
          wantedBy = [ "multi-user.target" ];
          requires = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          after = [ "network-online.target" "flatpak-repo.service" ];
          path = [ pkgs.flatpak ];
          serviceConfig = {
            Type = "oneshot";
            Restart = "on-failure";
            RestartSec = "30s";
          };
          script = ''
            if flatpak info --system ${ref} >/dev/null 2>&1; then
              exit 0
            fi

            flatpak install --system -y --noninteractive ${installArgs}

            mkdir -p ${lib.escapeShellArg stateDir}
            touch ${marker}
          '';
        };
      })

      (lib.mkIf (!enable) {
        systemd.services.${removeUnit} = {
          description = "Remove the ${appId} Flatpak";
          wantedBy = [ "multi-user.target" ];
          path = [ pkgs.flatpak ];
          serviceConfig.Type = "oneshot";
          script = ''
            if [ ! -e ${marker} ]; then
              exit 0
            fi

            if flatpak info --system ${ref} >/dev/null 2>&1; then
              flatpak uninstall --system -y --noninteractive ${ref}
            fi

            rm -f ${marker}
            flatpak uninstall --system -y --noninteractive --unused
          '';
        };
      })

      {
        system.activationScripts."mxFlatpak-${name}".text = ''
          ${config.systemd.package}/bin/systemctl restart --no-block \
            ${if enable then installUnit else removeUnit}.service || true
        '';
      }
    ];

  mkFlatpakApp =
    { name
    , option
    , appId
    , description
    , remote ? "flathub"
    , branch ? null
    , extraConfig ? { }
    }:
    let
      cfg = lib.getAttrFromPath option config;
    in
    {
      options = lib.setAttrByPath (option ++ [ "enable" ]) (lib.mkEnableOption description);

      config = lib.mkMerge [
        (mkFlatpakConfig { inherit name appId remote branch; enable = cfg.enable; })
        (lib.mkIf cfg.enable extraConfig)
      ];
    };
in
{
  inherit mkFlatpakApp mkFlatpakConfig;
}
