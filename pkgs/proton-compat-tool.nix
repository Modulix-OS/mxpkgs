{
  lib,
  stdenvNoCC,
  fetchzip,
}:
{
  pname,
  version,
  url,
  hash,
  vdfPlaceholder,
  steamDisplayName,
  dirName,
  homepage,
  license ? lib.licenses.bsd3,
  maintainers ? [ ],
}:

stdenvNoCC.mkDerivation {
  inherit pname version;

  src = fetchzip { inherit url hash; };

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  outputs = [
    "out"
    "steamcompattool"
  ];

  installPhase = ''
    runHook preInstall

    mkdir $steamcompattool
    ln -s $src/* $steamcompattool
    rm $steamcompattool/compatibilitytool.vdf
    cp $src/compatibilitytool.vdf $steamcompattool

    mkdir -p $out/share/steam/compatibilitytools.d $out/bin
    ln -s $steamcompattool $out/share/steam/compatibilitytools.d/${dirName}
    ln -s $steamcompattool/proton $out/bin/${dirName}

    runHook postInstall
  '';

  preFixup = ''
    substituteInPlace "$steamcompattool/compatibilitytool.vdf" \
      --replace-fail "${vdfPlaceholder}" "${steamDisplayName}"
  '';

  passthru = { inherit dirName; };

  meta = {
    description = ''
      Compatibility tool for Steam Play based on Wine and additional components.

      The `steamcompattool` output is meant for `programs.steam.extraCompatPackages`.
      The default output ships the same tree under
      `share/steam/compatibilitytools.d/${dirName}` and a `bin/${dirName}` entry
      point, for the launchers that do not read Steam's environment variables.
    '';
    inherit homepage license maintainers;
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
