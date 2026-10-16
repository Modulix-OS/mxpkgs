{
  callPackage,
  steamDisplayName ? "GE-Proton",
  version ? "11-9",
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
            "sha256-1o3sTPdQmIOKkm6qctt9lQfDEMCsysFyVfVK4sfRpw8="
          else if arch == "aarch64-linux" then
            "sha256-JtOnOLh127C4cU9s2EI3A2kzL2wvjF3t+XzQAJ90zow="
          else lib.fakeHash);

  vdfPlaceholder = "GE-Proton${version}-${archi}";
  dirName = "proton-ge";
  homepage = "https://github.com/GloriousEggroll/proton-ge-custom";
}
