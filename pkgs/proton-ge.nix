{
  callPackage,
  steamDisplayName ? "GE-Proton",
  version ? "11-12",
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
            "sha256-i20g9lDz7bR0SXWmvHZHztN4m8AHkcD0/OVGSC4ZzI8="
          else if arch == "aarch64-linux" then
            "sha256-0+ChUSgJa1IUl4yUIYAxP6hbY1oY48zzJYZkAcQZ/0Q="
          else lib.fakeHash);

  vdfPlaceholder = "GE-Proton${version}-${archi}";
  dirName = "proton-ge";
  homepage = "https://github.com/GloriousEggroll/proton-ge-custom";
}
