{
  callPackage,
  steamDisplayName ? "GE-Proton",
  version ? "11-6",
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
            "sha256-rX27DUrrrHtR1cgyr/424m9JPjrdASIisVGv2vWzMAs="
          else if arch == "aarch64-linux" then
            "sha256-sIwM++9FJzpIq4LkYQDL1TIfPFEnaVowrGT/3JPfPZk="
          else lib.fakeHash);

  vdfPlaceholder = "GE-Proton${version}-${archi}";
  dirName = "proton-ge";
  homepage = "https://github.com/GloriousEggroll/proton-ge-custom";
}
