# ModulixOS

A modular NixOS configuration framework managed with Flakes, designed to be imported as a foundation for building your own NixOS setup.

## Repository structure

```
.
├── flake.nix                        → Main flake declaration
├── flake.lock                       → Locked dependencies
├── lib/                             → Utility functions
│   ├── edid.nix                     → EDID helpers
│   └── normal-user.nix              → Standard user creation helper
├── modulixos/                       → Core system modules
│   ├── bluetooth.nix
│   ├── boot.nix
│   ├── dns.nix
│   ├── filesystem.nix
│   ├── fingerprint.nix
│   ├── ios-connect.nix
│   ├── network.nix
│   ├── nix-ld.nix
│   ├── patch-runner.nix
│   ├── powersave.nix
│   ├── sound.nix
│   ├── ssd.nix
│   ├── update.nix
│   ├── zram.nix
│   ├── desktop/                     → Desktop environments
│   │   ├── gnome/
│   │   ├── lxqt/
│   │   └── plasma/
│   ├── fonts/
│   ├── gpu/                         → GPU drivers and compute
│   │   ├── acceleration.nix
│   │   ├── compute.nix
│   │   └── nvidia.nix
│   ├── home-manager/                → Home Manager integration
│   ├── kernel/                      → Kernel variants
│   │   ├── gaming.nix
│   │   └── media.nix
│   ├── modulix-daemon/
│   ├── options/                     → Module option declarations
│   │   ├── framework.nix            → Framework laptop options
│   │   ├── hardware-gpu.nix
│   │   └── hardware.nix
│   └── security/
│       └── mitigations.nix
├── modules/                         → Optional programs and services
│   ├── fonts/
│   │   └── cooper-black.nix
│   ├── programs/
│   │   ├── creativity/              → Bambu Studio, Blender
│   │   ├── dev/                     → Arduino, dev tools
│   │   ├── games/                   → Steam, Heroic, Lutris, UMU
│   │   └── studio/                  → OBS Studio
│   └── services/
│       ├── docker/
│       ├── lamp/
│       ├── llm/
│       ├── printing/
│       ├── remote-desktop/
│       └── vm/
├── pkgs/                            → Custom packages
│   ├── kiwix.nix
│   ├── lsfg-vk.nix
│   ├── modulix-icon.nix
│   ├── mx-game.nix
│   ├── nix-clean.nix
│   ├── nix-update.nix
│   ├── phpmyadmin.nix
│   ├── proton-cachyos.nix
│   └── ...
├── patches/                         → System patches
│   ├── manifest.json
│   └── 0001-example.sh
├── scripts/
│   └── gen-manifest.sh
└── test/                            → Test VMs and evaluation
    ├── flake.nix
    ├── gpu-eval.nix
    └── vm-common.nix
```
