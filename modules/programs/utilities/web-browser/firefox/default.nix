{ config, lib, pkgs, pkgs-unstable, ... }:

let
  cfg = config.mx.programs.utilities.web-browser.firefox;
  gpu = config.mx.hardware.gpu;
  gnomeEnabled = config.mx.desktop == "gnome";

  vaapiVendor =
    if gpu.integrated.vendor != null then gpu.integrated.vendor
    else gpu.dedicated.vendor;
  nvidiaVaapi = vaapiVendor == "nvidia";

  mxDict = import ../../../../../lib/mx-dictionaries.nix { inherit lib pkgs; };

  langs = config.mx.languages;
  dictLanguages = mxDict.supported langs;
  dictlessLanguages = mxDict.unsupported langs;

  dictEnv = mxDict.hunspellEnv {
    name = "mx-firefox-dictionaries";
    langs = dictLanguages;
  };

  accelerationPrefs = lib.optionalAttrs cfg.hardwareAcceleration.enable ({
    "media.ffmpeg.vaapi.enabled" = true;
    "media.rdd-ffmpeg.enabled" = true;
    "media.hardware-video-decoding.force-enabled" = true;
    "media.navigator.mediadatadecoder_vpx_enabled" = true;
    "widget.dmabuf.force-enabled" = true;
  } // lib.optionalAttrs (!nvidiaVaapi && vaapiVendor != null) {
    "gfx.x11-egl.force-enabled" = true;
  });

  dictionaryPrefs = lib.optionalAttrs (dictLanguages != [ ]) {
    "spellchecker.dictionary_path" = "${dictEnv}/share/hunspell";
    "spellchecker.dictionary" = lib.concatStringsSep "," dictLanguages;
  };

  localePrefs = lib.optionalAttrs (langs != [ ]) {
    "intl.locale.requested" = lib.concatStringsSep "," langs;
  };

  providerLang = lib.head (lib.splitString "-" (lib.head (langs ++ [ "en" ])));

  searchProvider = pkgs.callPackage ../../../../../pkgs/mx-firefox-search-provider.nix {
    firefoxBin = "${config.programs.firefox.finalPackage}/bin/firefox";
    lang = providerLang;
  };
in
{
  options.mx.programs.utilities.web-browser.firefox = {
    enable = lib.mkEnableOption "Install Firefox";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs-unstable.firefox;
      defaultText = lib.literalExpression "pkgs-unstable.firefox";
      description = "Firefox package to install.";
    };

    hardwareAcceleration.enable = lib.mkOption {
      type = lib.types.bool;
      default = config.mx.hardware.gpu.acceleration.enable;
      defaultText = lib.literalExpression "config.mx.hardware.gpu.acceleration.enable";
      description = "VAAPI video decoding and dmabuf rendering in Firefox.";
    };

    searchProvider.enable = lib.mkOption {
      type = lib.types.bool;
      default = gnomeEnabled;
      defaultText = lib.literalExpression ''config.mx.desktop == "gnome"'';
      description = ''
        Register a GNOME Shell search provider turning what is typed in the
        activities overview into a Firefox search with the default engine.
      '';
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      mx.fonts.enable = true;

      warnings = map
        (lang: "mx.programs.utilities.web-browser.firefox: no hunspell dictionary for ${lang}, spell checking falls back to the Firefox default")
        dictlessLanguages;

      programs.firefox = {
        enable = true;
        package = lib.mkMxDefault cfg.package;
        languagePacks = lib.mkMxDefault langs;
        preferencesStatus = lib.mkMxDefault "default";
        preferences = lib.mkMxDefault (accelerationPrefs // dictionaryPrefs // localePrefs);
      };

      environment.sessionVariables = lib.mkIf (cfg.hardwareAcceleration.enable && nvidiaVaapi) {
        NVD_BACKEND = lib.mkMxDefault "direct";
      };
    }

    (lib.mkIf (cfg.searchProvider.enable && gnomeEnabled) {
      environment.systemPackages = [ searchProvider ];

      programs.dconf = {
        enable = true;
        profiles.user.databases = [{
          settings = {
            "org/gnome/desktop/search-providers".sort-order = [
              "org.gnome.Settings.desktop"
              "org.gnome.Contacts.desktop"
              "org.gnome.Nautilus.desktop"
              "firefox.desktop"
            ];
          };
        }];
      };
    })
  ]);
}
