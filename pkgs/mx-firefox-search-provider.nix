{ lib
, runCommand
, makeWrapper
, writeText
, python3
, glib
, firefoxBin ? "firefox"
, lang ? "en"
, busName ? "org.modulixos.FirefoxSearchProvider"
, objectPath ? "/org/modulixos/FirefoxSearchProvider"
, desktopId ? "firefox.desktop"
}:

let
  pythonEnv = python3.withPackages (ps: [ ps.pygobject3 ps.dbus-python ]);

  providerIni = writeText "${busName}.ini" ''
    [Shell Search Provider]
    DesktopId=${desktopId}
    BusName=${busName}
    ObjectPath=${objectPath}
    Version=2
  '';
in
runCommand "mx-firefox-search-provider" {
  nativeBuildInputs = [ makeWrapper ];
  passthru = { inherit busName objectPath; };
} ''
  makeWrapper ${pythonEnv}/bin/python3 $out/bin/mx-firefox-search-provider \
    --add-flags "${../lib/firefox-search-provider.py}" \
    --set-default MX_FIREFOX_BIN "${firefoxBin}" \
    --set-default MX_FIREFOX_SEARCH_LANG "${lang}" \
    --set-default MX_FIREFOX_SEARCH_BUS_NAME "${busName}" \
    --set-default MX_FIREFOX_SEARCH_OBJECT_PATH "${objectPath}" \
    --prefix GI_TYPELIB_PATH : "${glib}/lib/girepository-1.0"

  install -Dm444 ${providerIni} \
    $out/share/gnome-shell/search-providers/${busName}.ini

  mkdir -p $out/share/dbus-1/services
  printf '[D-BUS Service]\nName=%s\nExec=%s\n' \
    ${lib.escapeShellArg busName} "$out/bin/mx-firefox-search-provider" \
    > $out/share/dbus-1/services/${busName}.service
''
