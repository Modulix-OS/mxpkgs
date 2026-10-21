{ lib
, runCommand
, plymouth
, imagemagick
, logo
, watermarkVerticalAlignment ? 0.5
, logoWidth ? 960
}:

runCommand "modulix-plymouth-theme"
{
  nativeBuildInputs = [ imagemagick ];

  meta = {
    description = "Thème Plymouth Modulix (spinner avec le logo Modulix en grand)";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux;
  };
}
  ''
    DIR="$out/share/plymouth/themes/modulix"
    mkdir -p "$DIR"

    cp ${plymouth}/share/plymouth/themes/spinner/*.png "$DIR/"
    magick ${logo} -resize ${toString logoWidth}x "$DIR/watermark.png"

    sed -e '/^Name\[/d' \
        -e 's|^Name=.*|Name=Modulix|' \
        -e 's|^Description=.*|Description=Modulix logo centred on a black background, with the spinner below|' \
        -e "s|^ImageDir=.*|ImageDir=$DIR|" \
        -e 's|^WatermarkVerticalAlignment=.*|WatermarkVerticalAlignment=${toString watermarkVerticalAlignment}|' \
        ${plymouth}/share/plymouth/themes/spinner/spinner.plymouth \
        > "$DIR/modulix.plymouth"

    grep -q "^ImageDir=$DIR$" "$DIR/modulix.plymouth"
    grep -q '^WatermarkVerticalAlignment=${toString watermarkVerticalAlignment}$' "$DIR/modulix.plymouth"
    test -s "$DIR/watermark.png"
  ''
