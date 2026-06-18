{ lib
, stdenvNoCC
}:

let
  # Placeholder Modulix logo. Swap this SVG for the real branding asset.
  logo = builtins.toFile "modulix-logo.svg" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
      <rect x="4" y="4" width="40" height="40" rx="9" fill="#1565c0"/>
      <text x="24" y="32" font-family="sans-serif" font-size="26" font-weight="700"
            text-anchor="middle" fill="#ffffff">M</text>
    </svg>
  '';

  # Icon names Kickoff / launchers fall back to. Shipping all of them in
  # hicolor means the active theme's start-here is overridden by the logo.
  names = [
    "modulix-logo"
    "start-here"
    "start-here-kde"
    "start-here-kde-symbolic"
    "distributor-logo"
  ];
in
stdenvNoCC.mkDerivation {
  pname = "modulix-logo";
  version = "0.1";

  dontUnpack = true;
  dontWrapQtApps = true;

  installPhase = ''
    runHook preInstall

    DIR="$out/share/icons/hicolor/scalable/apps"
    mkdir -p "$DIR"
    for name in ${lib.concatStringsSep " " names}; do
      cp ${logo} "$DIR/$name.svg"
    done

    runHook postInstall
  '';

  meta = {
    description = "Modulix OS menu logo (placeholder, override the SVG)";
    license = lib.licenses.cc-by-sa-40;
    platforms = lib.platforms.linux;
  };
}
