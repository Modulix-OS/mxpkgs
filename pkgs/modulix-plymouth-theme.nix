{ lib
, runCommand
, plymouth
, watermarkVerticalAlignment ? 0.9
}:

runCommand "modulix-plymouth-theme"
{
  meta = {
    description = "Thème Plymouth Modulix (bgrt avec filigrane repositionné)";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux;
  };
}
  ''
    DIR="$out/share/plymouth/themes/modulix"
    mkdir -p "$DIR"

    sed -e '/^Name\[/d' \
        -e 's|^Name=.*|Name=Modulix|' \
        -e 's|^Description=.*|Description=Firmware BGRT background with the Modulix watermark|' \
        -e 's|^WatermarkVerticalAlignment=.*|WatermarkVerticalAlignment=${toString watermarkVerticalAlignment}|' \
        ${plymouth}/share/plymouth/themes/bgrt/bgrt.plymouth \
        > "$DIR/modulix.plymouth"

    grep -q '^WatermarkVerticalAlignment=${toString watermarkVerticalAlignment}$' "$DIR/modulix.plymouth"
  ''
