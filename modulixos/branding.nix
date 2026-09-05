{ pkgs, lib, config, ... }:

let
  cfg = config.mx.branding;
  homeUrl = "https://github.com/Modulix-OS";
  distroName = "Modulix OS";
  distroId = "modulixos";

  asciiCodeName = lib.replaceStrings
    [ "à" "â" "ä" "ç" "é" "è" "ê" "ë" "î" "ï" "ô" "ö" "ù" "û" "ü" " " ]
    [ "a" "a" "a" "c" "e" "e" "e" "e" "i" "i" "o" "o" "u" "u" "u" "-" ]
    (lib.toLower cfg.codeName);

  fullVersion = "${cfg.version} (${cfg.codeName})";
  prettyName = "${distroName} ${fullVersion}";
in
{
  options.mx.branding = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Identify the system as Modulix OS: distro name, version and id in
        {file}`/etc/os-release`, Modulix logo as the distributor icon, and the
        icon package installed system wide.
      '';
    };
    version = lib.mkOption {
      type = lib.types.str;
      default = "0.1";
      example = "1.0";
      description = ''
        Modulix OS release number. Drives `VERSION`, `VERSION_ID`, `CPE_NAME`
        and `PRETTY_NAME` in {file}`/etc/os-release`.

        This is the distro version, not the nixpkgs one:
        {option}`system.nixos.release` is read-only upstream and keeps tracking
        nixpkgs, as does {option}`system.stateVersion`. `BUILD_ID` is left
        alone too, so the nixpkgs revision a system was built from stays
        readable.
      '';
    };
    codeName = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "Lumière";
      description = ''
        Code name of the Modulix OS release, shown in `VERSION` and
        `PRETTY_NAME`. Lower-cased and stripped of its accents for
        `VERSION_CODENAME`, which os-release(5) restricts to `[a-z0-9._-]`.
      '';
    };
    logo = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../pkgs/modulix-logo.nix { };
      defaultText = lib.literalExpression "pkgs.modulix-logo";
      description = "Package providing the Modulix logo icons.";
    };
    iconName = lib.mkOption {
      type = lib.types.str;
      default = "modulix-logo";
      description = ''
        Icon name written as `LOGO=` in {file}`/etc/os-release`. Looked up in
        the icon theme by GNOME's About panel, fastfetch and KDE's system
        information page.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    system.nixos = {
      distroId = lib.mkMxDefault distroId;
      distroName = lib.mkMxDefault distroName;
      vendorId = lib.mkMxDefault distroId;
      vendorName = lib.mkMxDefault distroName;

      extraOSReleaseArgs = {
        VERSION = fullVersion;
        VERSION_ID = cfg.version;
        VERSION_CODENAME = asciiCodeName;
        PRETTY_NAME = prettyName;
        CPE_NAME = "cpe:/o:${distroId}:${distroId}:${cfg.version}";

        LOGO = cfg.iconName;
        HOME_URL = homeUrl;
        VENDOR_URL = homeUrl;
        DOCUMENTATION_URL = "${homeUrl}/mxpkgs";
        SUPPORT_URL = "${homeUrl}/mxpkgs/issues";
        BUG_REPORT_URL = "${homeUrl}/mxpkgs/issues";
        ANSI_COLOR = "0;38;2;114;155;217";
      };

      extraLSBReleaseArgs = {
        LSB_VERSION = fullVersion;
        DISTRIB_RELEASE = cfg.version;
        DISTRIB_CODENAME = asciiCodeName;
        DISTRIB_DESCRIPTION = prettyName;
      };
    };

    environment.systemPackages = [ cfg.logo ];
  };
}
