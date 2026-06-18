{ pkgs, config, lib, ... }:

let
  cfg = config.mx.fonts;
  cooper-black = import ./cooper-black.nix { inherit pkgs; };
in
{
  options.mx.fonts = {
    enable = lib.mkEnableOption "Enable advanced/creative fonts (pulled in by creative modules)";
  };

  config = lib.mkIf cfg.enable {
    fonts.packages = with pkgs; [
      cooper-black
      merriweather
      nerd-fonts._0xproto
      nerd-fonts.droid-sans-mono
      fira-code
      fira-code-symbols
      dina-font
      roboto
      lato
      league-spartan
      montserrat
      source-sans-pro
      raleway
      oswald
      poppins
    ];
  };
}
