{
  callPackage,
  steamDisplayName ? "Proton CachyOS",
  version ? "11.0-20261014-slr",
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
            "sha256-L0CzBfelMJP2jj4VNEQY/ZswJo16TN6nNf9qKVryCRU="
          else if arch == "aarch64-linux" then
            "sha256-KMCfVYTs1P+6JZ+T1qzZuj/jUja2rVdnFmOYQhV942w="
          else lib.fakeHash);

  vdfPlaceholder = "proton-cachyos-${version}-${archi}";
  dirName = "proton-cachyos";
  homepage = "https://github.com/CachyOS/proton-cachyos";
}
