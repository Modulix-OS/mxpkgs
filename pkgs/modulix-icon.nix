{ lib
, stdenvNoCC
, adwaita-icon-theme
, papirus-icon-theme
}:

stdenvNoCC.mkDerivation {
  pname = "modulix-icon-theme";
  version = adwaita-icon-theme.version;

  dontUnpack = true;
  dontWrapQtApps = true;   # <-- corrige l'erreur qtbase

  propagatedBuildInputs = [
    adwaita-icon-theme
    papirus-icon-theme
  ];

  installPhase = ''
    runHook preInstall

    ICONS_DIR="$out/share/icons"
    THEME_DIR="$ICONS_DIR/Modulix-OS"
    mkdir -p "$THEME_DIR"

    cp -r ${adwaita-icon-theme}/share/icons/Adwaita/. "$THEME_DIR/"
    chmod -R u+w "$THEME_DIR"

    sed -i 's/^Inherits=.*/Inherits=Papirus,hicolor/' "$THEME_DIR/index.theme"
    sed -i 's/^Name=.*/Name=Modulix-OS/'              "$THEME_DIR/index.theme"

    for theme in ${papirus-icon-theme}/share/icons/*Papirus*; do
      ln -s "$theme" "$ICONS_DIR/$(basename "$theme")"
    done

    runHook postInstall
  '';

  meta = {
    description = "Modulix OS icon theme (Adwaita + Papirus fallback)";
    license = lib.licenses.lgpl21Plus;
    platforms = lib.platforms.linux;
  };
}
