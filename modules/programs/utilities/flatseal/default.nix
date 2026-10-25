{ pkgs, config, lib, ... }:

(import ../../../../lib/flatpak-app.nix { inherit lib pkgs config; }).mkFlatpakApp {
  name = "flatseal";
  option = [ "mx" "programs" "utilities" "flatseal" ];
  appId = "com.github.tchx84.Flatseal";
  description = "Enable Flatseal, the Flatpak permission manager";
}
