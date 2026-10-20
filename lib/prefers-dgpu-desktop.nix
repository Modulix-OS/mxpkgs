{ runCommand, lib, package, desktopIds }:

runCommand "${package.pname or package.name}-prefers-dgpu" { } ''
  mkdir -p $out/share/applications
  for id in ${lib.escapeShellArgs desktopIds}; do
    src="${package}/share/applications/$id.desktop"
    [ -e "$src" ] || continue
    sed '/^\[Desktop Entry\]/a PrefersNonDefaultGPU=true' "$src" \
      > "$out/share/applications/$id.desktop"
  done
''
