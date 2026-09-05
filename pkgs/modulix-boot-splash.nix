{ lib
, runCommand
, librsvg
, imagemagick
, logo ? ../assets/modulix-logo.svg
, width ? 1920
, height ? 1080
, background ? "#0d1117"
, splashLogoSize ? 512
, plymouthLogoSize ? 64
}:

runCommand "modulix-boot-splash"
{
  nativeBuildInputs = [ librsvg imagemagick ];

  meta = {
    description = "Modulix OS boot splash (fond Limine + logo Plymouth)";
    license = lib.licenses.cc-by-sa-40;
    platforms = lib.platforms.linux;
  };
}
  ''
    DIR="$out/share/modulix"
    mkdir -p "$DIR"

    rsvg-convert -w ${toString plymouthLogoSize} -h ${toString plymouthLogoSize} \
      ${logo} -o "$DIR/logo.png"
    rsvg-convert -w ${toString splashLogoSize} -h ${toString splashLogoSize} \
      ${logo} -o splash-logo.png

    magick -size ${toString width}x${toString height} xc:'${background}' \
      splash-logo.png -gravity center -composite \
      png24:"$DIR/splash.png"
  ''
