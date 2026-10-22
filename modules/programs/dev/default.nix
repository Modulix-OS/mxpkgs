{ pkgs, config, lib, ... }:

let
  cfg = config.mx.programs.dev;

  defaultTerminal = {
    gnome = pkgs.gnome-console;
    plasma = pkgs.kdePackages.konsole;
    lxqt = pkgs.lxqt.qterminal;
    cli = null;
  }.${config.mx.desktop};
in
{
  imports = [
    ./arduino
    ./vscode
    ./git
    ./distrobox
    ./ue5
  ];

  options.mx.programs.dev = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.arduino.enable || cfg.vscode.enable || cfg.git.enable || cfg.distrobox.enable || cfg.ue5.enable;
      defaultText = lib.literalExpression "any development module enabled";
      description = ''
        Whether the shared development tooling is active (auto: any
        development module enabled). It installs a terminal and a process
        monitor, which every child needs and no single one should own.
      '';
    };

    terminal = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = defaultTerminal;
      defaultText = lib.literalExpression "the terminal of the chosen desktop, null on mx.desktop = \"cli\"";
      description = ''
        Terminal emulator installed alongside the development tooling. The
        desktop base pack usually ships the same one, so the two collapse into
        a single store path; it is also what makes the Ubuntu container's
        Terminal=true launcher work on any desktop. Set it to null to install
        none.
      '';
    };

    monitor = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.htop;
      defaultText = lib.literalExpression "pkgs.htop";
      description = "Process monitor installed alongside the development tooling; null to install none.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages =
      lib.optional (cfg.terminal != null) cfg.terminal
      ++ lib.optional (cfg.monitor != null) cfg.monitor;
  };
}
