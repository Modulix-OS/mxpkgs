# `mx.hardware.gpu` — options to define

Options a user sets in their host configuration. Internal / `readOnly` options
(`*.computing`, `integrated.launcher`) are derived automatically and listed at the
end for reference only.

## 1. GPU slots

Two slots: `dedicated` (discrete card) and `integrated` (iGPU). Both have the same
option set. Leave a slot's `vendor` at `null` when that GPU does not exist.

| Option | Type | Default | Purpose |
| --- | --- | --- | --- |
| `mx.hardware.gpu.dedicated.vendor` | `null \| "amd" \| "nvidia" \| "intel"` | `null` | Discrete GPU vendor. Drives driver choice, VAAPI driver, compute stack, Proton upscaler flags. |
| `mx.hardware.gpu.dedicated.generation` | `null \| string` | `null` | Architecture codename (see table below). Drives NVIDIA legacy driver branch, Intel VAAPI driver, FSR/XeSS upgrades. |
| `mx.hardware.gpu.dedicated.pciId` | `null \| string` | `null` | `vendor:device` from `lspci -nn`, e.g. `"10de:2484"`. Used for `MESA_VK_DEVICE_SELECT`. |
| `mx.hardware.gpu.dedicated.pciAddr` | `null \| string` | `null` | PCI address from `lspci`, e.g. `"01:00.0"`. Used for `DRI_PRIME`. |
| `mx.hardware.gpu.dedicated.drmIndex` | `null \| int` | `null` | Card index in `/sys/class/drm`, e.g. `0`. Used for the MangoHud `gpu_list`. |
| `mx.hardware.gpu.integrated.vendor` | `null \| "amd" \| "nvidia" \| "intel"` | `null` | iGPU vendor. The iGPU is the **primary** GPU for `LIBVA_DRIVER_NAME`. |
| `mx.hardware.gpu.integrated.generation` | `null \| string` | `null` | Same semantics as above. |
| `mx.hardware.gpu.integrated.pciId` | `null \| string` | `null` | Enables the `igpu-launch` wrapper when set. |
| `mx.hardware.gpu.integrated.pciAddr` | `null \| string` | `null` | Adds `DRI_PRIME` to `igpu-launch`. |
| `mx.hardware.gpu.integrated.drmIndex` | `null \| int` | `null` (treated as `1`) | MangoHud `gpu_list` value inside `igpu-launch`. |

### Accepted `generation` values

| Vendor | Codenames |
| --- | --- |
| `nvidia` | `fermi`, `kepler`, `maxwell`, `pascal`, `volta`, `turing`, `ampere`, `ada-lovelace`, `blackwell` |
| `amd` | `rdna2`, `rdna3`, `rdna4`, … |
| `intel` | `ironlake`, `sandybridge`, `ivybridge`, `haswell`, `broadwell`, `skylake`, `tigerlake`, `arc`, … |

Type is free-form `str` — a typo fails silently (no assertion), so copy exactly.

### What `generation` actually changes

- **NVIDIA driver branch**: `fermi` → `legacy_390`, `kepler` → `legacy_470`,
  `maxwell`/`pascal`/`volta` → `legacy_580`. Any legacy branch also forces
  `pkgs.linuxPackages` (LTS kernel), disables the CachyOS kernel, and disables
  the open kernel module.
- **Intel VAAPI**: `ironlake`/`sandybridge`/`ivybridge`/`haswell`/`westmere` →
  `intel-vaapi-driver` + `i965`; everything else → `intel-media-driver` + `iHD`.
- **Proton upscalers** (primary GPU): `rdna4` → `PROTON_FSR4_UPGRADE`,
  `rdna3` → `PROTON_FSR3_UPGRADE` (or FSR4 with `mx.programs.games.force-fsr4-for-rdna3`),
  AMD non-`rdna4` / Intel → `PROTON_XESS_UPGRADE`.

### How to find the values

```sh
lspci -nn | grep -Ei 'vga|3d|display'
#   01:00.0 VGA compatible controller [0300]: NVIDIA ... [10de:2484] (rev a1)
#   ^pciAddr                                              ^pciId

ls -l /sys/class/drm/card*/device   # card0, card1 … → drmIndex
```

## 2. Video acceleration

| Option | Type | Default | Purpose |
| --- | --- | --- | --- |
| `mx.hardware.gpu.acceleration.enable` | `bool` | `!config.mx.mode.server.enable` | VAAPI / VDPAU stack. Enables `hardware.graphics`, installs vendor drivers, sets `LIBVA_DRIVER_NAME` from the primary GPU (iGPU first, else dedicated), and `MOZ_DISABLE_RDD_SANDBOX=1` when the dedicated GPU is NVIDIA. |

## 3. Hybrid laptops

| Option | Type | Default | Purpose |
| --- | --- | --- | --- |
| `mx.hardware.gpu.hybrid.enable` | `bool` | both slots have a `vendor` | Runs `switcheroo-control`, without which the `PrefersNonDefaultGPU` key of a `.desktop` entry is a no-op on GNOME and Plasma alike. |

Applications that must not start on the iGPU ship a `.desktop` override built by
`lib/prefers-dgpu-desktop.nix` and installed at `lib.hiPrio`, which is what both
DaVinci Resolve modules do — see [`davinci-resolve.md`](davinci-resolve.md).
`switcheroo-control` reads `boot_vga` from sysfs to tell the default GPU from the
discrete one, so a desktop whose discrete card already drives the display is left
alone. The routing only applies to launches from the desktop, not from a terminal.

## 4. Compute

| Option | Type | Default | Purpose |
| --- | --- | --- | --- |
| `mx.hardware.gpu.compute.enable` | `bool` | `false` | ROCm / CUDA / oneAPI / OpenCL runtimes. Auto-enabled by `blender`, `obs-studio`, both `davinci-resolve` modules, and the `llm` service. |
| `mx.hardware.gpu.compute.rusticl.enable` | `bool` | `false` | Second OpenCL ICD (Mesa rusticl) next to the ROCm one. Off by default: both enumerate the same boards, so OpenCL applications list every GPU twice. Turn it on for AMD GPUs the ROCm runtime does not enumerate. |
| `mx.hardware.gpu.compute.rocmStack.enable` | `bool` | `false` | Full ROCm/HIP stack on top of the OpenCL baseline. Needed by HIP applications (Blender, llama.cpp) only. **Triggers large rebuilds.** |
| `mx.hardware.gpu.compute.nvidiaOffloadEnv.enable` | `bool` | `false` | Sets `__NV_PRIME_RENDER_OFFLOAD` and `__GLX_VENDOR_LIBRARY_NAME` system-wide. Off by default: it routes every GL client to the discrete GPU. |

Effects per detected stack:

- `rocm` → `hardware.amdgpu.opencl.enable`, that is the `amdocl64.icd` ICD alone.
  `mesa.opencl` and `RUSTICL_ENABLE=radeonsi` come with `compute.rusticl.enable`,
  and the `/opt/rocm` tree, `ROC_ENABLE_PRE_VEGA=1` and
  `nixpkgs.config.rocmSupport` with `compute.rocmStack.enable` — OpenCL-only
  consumers such as DaVinci Resolve leave both off.
- `oneapi` → `intel-compute-runtime` (`intel-compute-runtime-legacy1` on Gen 8/9/11),
  plus `hardware.graphics.enable32Bit`.
- `cuda` → nothing system-wide; handled per application via `cudaSupport`.

## 5. NVIDIA specifics

Only meaningful when `dedicated.vendor = "nvidia"`.

| Option | Type | Default | Purpose |
| --- | --- | --- | --- |
| `mx.hardware.gpu.nvidia.disable` | `bool` | `false` | Fully powers off the discrete NVIDIA card (udev removal + module blacklist). **Laptop only.** |
| `mx.hardware.gpu.nvidia.nvidiaBusId` | `null \| string` | `null` | PRIME bus id of the NVIDIA card, NixOS format: `"PCI:1:0:0"`. |
| `mx.hardware.gpu.nvidia.intelBusId` | `null \| string` | `null` | PRIME bus id of the Intel iGPU, e.g. `"PCI:0:2:0"`. |
| `mx.hardware.gpu.nvidia.amdBusId` | `null \| string` | `null` | PRIME bus id of the AMD iGPU. |
| `mx.hardware.gpu.nvidia.experimental-power-management` | `bool` | `false` | Enables `powerManagement.finegrained` (ignored on legacy drivers). |

### Assertions to respect

- `intelBusId` and `amdBusId` are mutually exclusive.
- On a laptop with `disable = false`, setting `nvidiaBusId` requires one of
  `intelBusId` / `amdBusId`.
- `disable = true` requires `mx.hardware.laptop = true`.
- `intelBusId` requires `integrated.vendor = "intel"`.
- `amdBusId` requires `integrated.vendor = "amd"`.

Bus id format differs from `pciAddr`: `lspci` prints `01:00.0`, NixOS wants
`PCI:1:0:0` (decimal, colon-separated, no leading zeros).

## 6. Examples

### Desktop, single AMD card

```nix
mx.hardware.gpu.dedicated = {
  vendor = "amd";
  generation = "rdna3";
  pciId = "1002:744c";
  pciAddr = "03:00.0";
  drmIndex = 0;
};
```

### Laptop, Intel iGPU + NVIDIA dGPU (PRIME)

```nix
mx.hardware.laptop = true;

mx.hardware.gpu = {
  integrated = {
    vendor = "intel";
    generation = "tigerlake";
    pciId = "8086:9a49";
    pciAddr = "00:02.0";
    drmIndex = 1;
  };
  dedicated = {
    vendor = "nvidia";
    generation = "ampere";
    pciId = "10de:249d";
    pciAddr = "01:00.0";
    drmIndex = 0;
  };
  nvidia = {
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:1:0:0";
    experimental-power-management = true;
  };
};
```

### Laptop with the NVIDIA card switched off

```nix
mx.hardware.laptop = true;
mx.hardware.gpu.integrated.vendor = "intel";
mx.hardware.gpu.dedicated.vendor = "nvidia";
mx.hardware.gpu.nvidia.disable = true;
```

### Headless / server

```nix
mx.hardware.gpu.dedicated.vendor = null;
mx.hardware.gpu.acceleration.enable = false;
```

Video drivers fall back to `[ "modesetting" ]` when both slots are `null`.

## 7. Renamed options (backwards compatibility)

| Old | New |
| --- | --- |
| `mx.hardware.gpu.vendor` | `mx.hardware.gpu.dedicated.vendor` |
| `mx.hardware.gpu.generation` | `mx.hardware.gpu.dedicated.generation` |
| `mx.hardware.gpu.igpu.vendor` | `mx.hardware.gpu.integrated.vendor` |
| `mx.hardware.gpu.igpu.generation` | `mx.hardware.gpu.integrated.generation` |

## 8. Derived — do not set

| Option | Value |
| --- | --- |
| `mx.hardware.gpu.<slot>.computing` | `"cuda"` (nvidia), `"rocm"` (amd), `"oneapi"` (intel), `"cpu"` (`null`) |
| `mx.hardware.gpu.integrated.launcher` | `igpu-launch` wrapper package, or `null` when `integrated.pciId` is unset |

Helper functions in `lib/mx-gpuStack.nix`: `mxGpuStacks`, `mxGpuHasStack`,
`mxGpuPrimary`, `mxGpuVideoDrivers`.
