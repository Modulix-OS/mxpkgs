{
  callPackage,
  steamDisplayName ? "GE-Proton",
  version ? "11-14",
  arch,
  lib
}:

let
  archi = (if arch == "x86_64-linux" then
            "x86_64"
          else if arch == "aarch64-linux" then
            "aarch64"
          else "");
in
callPackage ./proton-compat-tool.nix { } {
  pname = "proton-ge-bin";
  inherit version steamDisplayName;

  url = "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton${version}/GE-Proton${version}-${archi}.tar.gz";
  hash = (if arch == "x86_64-linux" then
            "sha256-Bru3l0AqrvDl+XYC1dYhmy5XqKP49yFjWVJwZzel60Q="
          else if arch == "aarch64-linux" then
            "sha256-n51sElFtNZQRJOpWdH1jpg+H0Wq7Q6TjCtg1wl3a44Y="
          else lib.fakeHash);

  vdfPlaceholder = "GE-Proton${version}-${archi}";
  dirName = "proton-ge";
  homepage = "https://github.com/GloriousEggroll/proton-ge-custom";
}
