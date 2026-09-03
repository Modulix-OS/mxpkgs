{ lib }:
let
  schemaDir = p: "${p}/share/gsettings-schemas/${p.name}";

  wrapGsettingsSchemas =
    { pkgs, package, binaries, extraSchemaPackages ? [] }:
    let
      schemaPackages = [ pkgs.gsettings-desktop-schemas pkgs.gtk3 ] ++ extraSchemaPackages;
      prefixArgs = map (p: ''--prefix XDG_DATA_DIRS : "${schemaDir p}"'') schemaPackages;
      wrap = bin: ''
        wrapProgram $out/bin/${bin} \
          ${lib.concatStringsSep " \\\n          " prefixArgs}
      '';
    in
    package.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.makeWrapper ];
      postFixup = (old.postFixup or "") + lib.concatMapStrings wrap binaries;
    });
in
{
  inherit wrapGsettingsSchemas;

  mkGsettingsOverlay = entries: (final: prev:
    lib.listToAttrs (map
      (entry: {
        inherit (entry) name;
        value = wrapGsettingsSchemas {
          pkgs = final;
          package = prev.${entry.name};
          binaries = entry.binaries or [ entry.name ];
          extraSchemaPackages = entry.extraSchemaPackages or [];
        };
      })
      entries));
}
