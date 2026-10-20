{ ... }:
{
  imports = [
    ./compute.nix
    ./acceleration.nix
    ./nvidia.nix
    ./igpu-launch.nix
    ./hybrid.nix
  ];
}
