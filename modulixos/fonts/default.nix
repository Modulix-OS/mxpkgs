{ pkgs, ... }:

let
  mx-use-system-font = pkgs.writeShellScriptBin "mx-use-system-font" ''
    mkdir -p ~/.local/share/fonts
    for dir in /nix/store/*/share/fonts/*; do
      [ -d "$dir" ] || continue
      cp -r $dir/* ~/.local/share/fonts/ 1>/dev/null 2>/dev/null
    done
    chmod 644 ~/.local/share/fonts/* 1>/dev/null 2>/dev/null
  '';
in
{
  # Basic system font set — always present.
  environment.systemPackages = [
    mx-use-system-font
  ];
  fonts.packages = with pkgs; [
    dejavu_fonts
    freefont_ttf
    gyre-fonts # TrueType substitutes for standard PostScript fonts
    liberation_ttf
    unifont
    noto-fonts
    noto-fonts-color-emoji
    noto-fonts-cjk-sans
  ];
}
