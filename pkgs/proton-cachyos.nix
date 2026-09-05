{
  callPackage,
  steamDisplayName ? "Proton CachyOS",
  version ? "11.0-20260703-slr",
  arch,
  lib
}:

let
  archi = (if arch == "x86_64-linux" then
            "x86_64"
          else if arch == "aarch64-linux" then
            "arm64"
          else "");
in
callPackage ./proton-compat-tool.nix { } {
  pname = "proton-cachyos-bin";
  inherit version steamDisplayName;

  url = "https://github.com/CachyOS/proton-cachyos/releases/download/cachyos-${version}/proton-cachyos-${version}-${archi}.tar.xz";
  hash = (if arch == "x86_64-linux" then
            "sha256-jOcPeEkBBPPNqyjXBoHm1Nk8AexPiLhx5+385NjUPT0="
          else if arch == "aarch64-linux" then
            "sha256-1KuZ5L0+qaPFU8P5yJVybnryD3rm+E1o/trv9+nvA7k="
          else lib.fakeHash);

  vdfPlaceholder = "proton-cachyos-${version}-${archi}";
  dirName = "proton-cachyos";
  homepage = "https://github.com/CachyOS/proton-cachyos";
}
