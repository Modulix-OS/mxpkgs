# Shared tweaks for the test VMs. Imports the QEMU VM module so
# `config.system.build.vm` exists and `virtualisation.*` options are valid.
{ pkgs, lib, config, modulesPath, ... }:

let
  user = "mainuser";
  isGraphical = config.mx.desktop != "cli";
in
{
  imports = [
    "${modulesPath}/virtualisation/qemu-vm.nix"
  ];

  # Limine bootloader is host hardware only — let qemu-vm handle boot.
  mx.bootloader.enable = false;
  mx.hardware.gpu.vendor = null;


  # Standard NixOS user declaration (no mx.main-user module in the tree).
  users.users.${user} = {
    isNormalUser = true;
    description = "Test User";
    initialPassword = "1234";
    extraGroups = [ "wheel" "networkmanager" ];
  };

  # Auto-login so the chosen desktop comes up without typing the password.
  services.displayManager.autoLogin = lib.mkIf isGraphical {
    enable = true;
    inherit user;
  };
  services.getty.autologinUser = lib.mkIf (!isGraphical) user;

  # VM resources + virtio GPU (needed for a usable Plasma/GNOME Wayland session).
  virtualisation = {
    memorySize = 4096;
    cores = 4;
    diskSize = 16384;
    qemu.options = [
      "-vga none"
      "-device virtio-vga-gl"
      "-display gtk,gl=on"
    ];
  };

  networking.hostName = "mx-test-${config.mx.desktop}";
  time.timeZone = lib.mkDefault "Europe/Paris";
}
