{
  lib,
  stdenv,
  fetchFromGitHub,
  meson,
  ninja,
  pkg-config,
  glib,
  gobject-introspection,
  atk,
  cairo,
  graphene,
  gsettings-desktop-schemas,
  lcms2,
  libGL,
  libxkbcommon,
  pixman,
  wayland,
  libx11,
  libxfixes,
  libxi,
  mutter,
}:

stdenv.mkDerivation {
  pname = "gnome-rounded-blur";
  version = "v1.0.2";

  src = fetchFromGitHub {
    owner = "kancko";
    repo = "gnome-rounded-blur";
    tag = "v1.0.2";
    hash = "sha256-2zRQnORmVQMuubLOZ+0mHDQhDoc7V/+2JM3gmYPia2s=";
  };

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    glib
    gobject-introspection
  ];

  buildInputs = [
    glib
    mutter
    atk
    cairo
    graphene
    gsettings-desktop-schemas
    lcms2
    libGL
    libxkbcommon
    pixman
    wayland
    libx11
    libxfixes
    libxi
  ];

  postFixup = ''
    patchelf --add-rpath "$(echo ${mutter}/lib/mutter-*)" "$out/lib/libblur-effect-1.0.so.1.0.0"
  '';

  meta = {
    description = "Blur.BlurEffect with corner radius support for GNOME Shell extensions";
    homepage = "https://github.com/kancko/gnome-rounded-blur";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
    maintainers = [ ];
  };
}
