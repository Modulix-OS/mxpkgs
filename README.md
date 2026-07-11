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

## Patch system (remote hotfixes)

`mx.services.patch-runner` applies hotfix scripts hosted in this repo's
`patches/` directory **between full `nixos-rebuild` runs**. A systemd timer
periodically fetches `patches/manifest.json`, and runs every patch whose `id`
is newer than the last one applied (state in `/var/lib/patch-runner/version`).

Security model:

- **Transport**: HTTPS to `raw.githubusercontent.com`.
- **Integrity**: each patch's `sha256` is listed in the manifest and verified
  before execution (fail-closed — a mismatch aborts and does not advance state).
- **Authenticity**: optional `minisign` signature of the manifest, verified
  against a public key **pinned in the Nix config**. The `sha256` alone does not
  protect against a malicious manifest (whoever pushes the patch also pushes the
  hash); the signature does. **Set `publicKey` for any serious use.**

Enable on a host:

```nix
mx.services.patch-runner = {
  enable    = true;
  publicKey = "RW...";        # minisign public key (omit to disable signature check — not recommended)
  ref       = "main";         # pin a commit instead of a branch for immutability
  interval  = "daily";        # systemd OnCalendar
};
```

### Authoring a patch

1. Add `patches/NNNN-description.sh` (zero-padded, strictly increasing id, never
   renumber or rewrite a published patch). Make it **idempotent** — it may be
   retried after a partial run.
2. Regenerate the manifest:
   ```bash
   nix shell nixpkgs#jq -c bash scripts/gen-manifest.sh
   ```
3. Sign it (required if hosts pin a `publicKey`):
   ```bash
   minisign -Sm patches/manifest.json   # produces patches/manifest.json.minisig
   ```
4. Commit the patch, `manifest.json`, and `manifest.json.minisig` together.

The `patches-manifest` CI workflow fails the PR if `manifest.json` is stale.
