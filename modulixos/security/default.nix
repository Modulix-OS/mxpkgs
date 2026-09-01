{ lib, config, ... }:

{
  imports = [
    ./mitigations.nix
  ];

  security.rtkit.enable = true;
  security.apparmor.enable = false;
  services.gnome.gnome-keyring.enable = !config.mx.mode.server.enable;
  security.pam.services.login.enableGnomeKeyring = lib.mkMxDefault (!config.mx.mode.server.enable);

  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;
    tctiEnvironment.enable = true;
  };

  boot.initrd.systemd = {
    enable = true;
    tpm2.enable = true;
  };

  security.polkit.enable = true;
}
