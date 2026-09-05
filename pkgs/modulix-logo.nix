{ lib
, stdenvNoCC
, librsvg
}:

let

  logo = ../assets/modulix-logo.svg;

  names = [
    "modulix-logo"
    "modulix-logo-text"
    "modulix-logo-text-dark"
    "start-here"
    "start-here-kde"
    "start-here-kde-symbolic"
    "distributor-logo"
  ];

  sizes = [ 16 22 24 32 48 64 128 256 ];
in
stdenvNoCC.mkDerivation {
  pname = "modulix-logo";
  version = "0.1";

  dontUnpack = true;
  dontWrapQtApps = true;

  nativeBuildInputs = [ librsvg ];

  installPhase = ''
    runHook preInstall

    ICONS="$out/share/icons/hicolor"

    mkdir -p "$ICONS/scalable/apps"
    for name in ${lib.concatStringsSep " " names}; do
      cp ${logo} "$ICONS/scalable/apps/$name.svg"
    done

    for size in ${lib.concatStringsSep " " (map toString sizes)}; do
      DIR="$ICONS/''${size}x''${size}/apps"
      mkdir -p "$DIR"
      rsvg-convert -w "$size" -h "$size" ${logo} -o raster.png
      for name in ${lib.concatStringsSep " " names}; do
        cp raster.png "$DIR/$name.png"
      done
    done

    runHook postInstall
  '';

  meta = {
    description = "Modulix OS logo icons (menu, distributor logo, GDM)";
    license = lib.licenses.cc-by-sa-40;
    platforms = lib.platforms.linux;
  };
}
