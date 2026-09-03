{ lib, ... }:
let
  fix = import ../lib/package-fix.nix { inherit lib; };

  gsettingsPackages = [
    { name = "texstudio"; binaries = [ "texstudio" ]; }
    { name = "kiwix";     binaries = [ "kiwix-desktop" ]; }
    { name = "goverlay";  binaries = [ "goverlay" ]; }
  ];
in
{
  nixpkgs.overlays = [ (fix.mkGsettingsOverlay gsettingsPackages) ];
}
