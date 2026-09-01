{ lib, ... }:

{
  boot.kernel.sysctl = {
    "vm.swappiness" = lib.mkMxDefault 100;
  };
  zramSwap = {
    enable = lib.mkMxDefault true;
    algorithm = lib.mkMxDefault "zstd";
    memoryPercent = lib.mkMxDefault 100;
    priority = lib.mkMxDefault 100;
  };
  services.udev.extraRules = ''
    ACTION=="change", KERNEL=="zram0", ATTR{initstate}=="1", SYSCTL{vm.swappiness}="150", RUN+="/bin/sh -c 'echo N > /sys/module/zswap/parameters/enabled'"
  '';
}
