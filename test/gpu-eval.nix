# GPU module evaluation tests.
#
# Pure-eval assertions over modulixos/gpu/{acceleration,compute}.nix across vendors,
# hybrid laptops and Intel codenames. Only GPU-related options are forced, and games is
# forced off, so this never builds the full system (and dodges unrelated WIP module bugs).
#
# Run:
#   cd test
#   nix eval  .#gpuEval.x86_64-linux --json | jq      # inspect computed results
#   nix build .#checks.x86_64-linux.gpu               # assert expectations (PASS = build ok)
#
{ lib, pkgs, baseSystem }:

let
  # mkForce, spelled out so this file needs no module-system lib in scope at the call site.
  ov = v: { _type = "override"; priority = 50; content = v; };

  cfgOf = mod: (baseSystem.extendModules { modules = [ mod ]; }).config;

  gpu = g: { mx.hardware.gpu = g; };

  rawNames = c: map (p: p.pname or p.name or "?") c.hardware.graphics.extraPackages;
  names = c: lib.sort (a: b: a < b) (rawNames c);
  has = c: n: lib.elem n (rawNames c);
  count = c: n: lib.count (x: x == n) (rawNames c);
  libva = c: c.environment.sessionVariables.LIBVA_DRIVER_NAME or null;
  moz = c: c.environment.sessionVariables.MOZ_DISABLE_RDD_SANDBOX or null;

  # ---- scenarios -----------------------------------------------------------
  c = {
    base         = cfgOf {};
    amd          = cfgOf (gpu { dedicated = { vendor = ov "amd"; generation = "rdna3"; }; });
    amdCompute   = cfgOf (gpu { dedicated = { vendor = ov "amd"; generation = "rdna3"; }; compute.enable = true; });
    intelHaswell = cfgOf (gpu { dedicated = { vendor = ov "intel"; generation = "haswell"; }; });
    intelTiger   = cfgOf (gpu { dedicated = { vendor = ov "intel"; generation = "tigerlake"; }; });
    intelNull    = cfgOf (gpu { dedicated.vendor = ov "intel"; });             # null gen -> modern
    intelCompute = cfgOf (gpu { dedicated.vendor = ov "intel"; compute.enable = true; });
    nvidia       = cfgOf (gpu { dedicated = { vendor = ov "nvidia"; generation = "ampere"; }; });
    nvidiaCompute= cfgOf (gpu { dedicated = { vendor = ov "nvidia"; generation = "ampere"; }; compute.enable = true; });
    hybridIntel  = cfgOf (gpu { dedicated = { vendor = ov "nvidia"; generation = "ampere"; }; integrated = { vendor = "intel"; generation = "tigerlake"; }; });
    hybridAmd    = cfgOf (gpu { dedicated = { vendor = ov "nvidia"; generation = "ampere"; }; integrated = { vendor = "amd"; generation = "rdna2"; }; });
    hybridCompute= cfgOf (gpu { dedicated = { vendor = ov "nvidia"; generation = "ampere"; }; integrated = { vendor = "intel"; generation = "tigerlake"; }; compute.enable = true; });
    hybridAmdCompute = cfgOf (gpu { dedicated = { vendor = ov "nvidia"; generation = "ampere"; }; integrated = { vendor = "amd"; generation = "rdna2"; }; compute.enable = true; });
    igpuOnly     = cfgOf (gpu { dedicated.vendor = ov null; integrated = { vendor = "amd"; generation = "rdna2"; }; compute.enable = true; });
    igpuLauncher = cfgOf (gpu { dedicated.vendor = ov null; integrated = { vendor = "intel"; pciId = "8086:46a6"; pciAddr = "00:02.0"; drmIndex = 1; }; });
  };

  # Slot layout of a scenario, fed to the pure lib.mxGpu* helpers.
  layout = cc: cc.mx.hardware.gpu;

  # ---- machine-readable results (for `nix eval .#gpuEval`) ------------------
  results = lib.mapAttrs (_: cc: {
    libva = libva cc;
    moz = moz cc;
    computing = {
      dedicated = cc.mx.hardware.gpu.dedicated.computing;
      integrated = cc.mx.hardware.gpu.integrated.computing;
    };
    accelEnable = cc.mx.hardware.gpu.acceleration.enable;
    amdgpuOpencl = cc.hardware.amdgpu.opencl.enable;
    pkgs = names cc;
  }) c;

  # ---- assertions ----------------------------------------------------------
  expect = name: got: want:
    if got == want then true
    else throw "gpu-eval [${name}]: got ${builtins.toJSON got}, expected ${builtins.toJSON want}";

  checks = [
    # base: vendor=null -> accel on (non-server), no driver, no packages
    (expect "base.libva"        (libva c.base) null)
    (expect "base.pkgs"         (names c.base) [])
    (expect "base.accelEnable"  c.base.mx.hardware.gpu.acceleration.enable true)

    # amd: radeonsi via mesa, no extra accel package
    (expect "amd.libva"         (libva c.amd) "radeonsi")
    (expect "amd.pkgs"          (names c.amd) [])

    # intel codename -> driver
    (expect "intelHaswell.libva"      (libva c.intelHaswell) "i965")
    (expect "intelHaswell.i965"       (has c.intelHaswell "intel-vaapi-driver") true)
    (expect "intelHaswell.no-iHD"     (has c.intelHaswell "intel-media-driver") false)
    (expect "intelTiger.libva"        (libva c.intelTiger) "iHD")
    (expect "intelTiger.iHD"          (has c.intelTiger "intel-media-driver") true)
    (expect "intelTiger.qsv"          (has c.intelTiger "vpl-gpu-rt") true)
    (expect "intelTiger.no-i965"      (has c.intelTiger "intel-vaapi-driver") false)
    (expect "intelNull.libva"         (libva c.intelNull) "iHD")               # null -> modern default

    # nvidia accel
    (expect "nvidia.libva"      (libva c.nvidia) "nvidia")
    (expect "nvidia.vaapi"      (has c.nvidia "nvidia-vaapi-driver") true)
    (expect "nvidia.vdpau"      (has c.nvidia "libva-vdpau-driver") true)
    (expect "nvidia.moz"        (moz c.nvidia) "1")

    # hybrid nvidia + intel iGPU: BOTH drivers, iGPU drives display -> iHD
    (expect "hybridIntel.libva"  (libva c.hybridIntel) "iHD")
    (expect "hybridIntel.nv"     (has c.hybridIntel "nvidia-vaapi-driver") true)
    (expect "hybridIntel.intel"  (has c.hybridIntel "intel-media-driver") true)
    (expect "hybridIntel.moz"    (moz c.hybridIntel) "1")
    (expect "hybridIntel.dedup"  (count c.hybridIntel "libvdpau-va-gl") 1)     # lib.unique

    # hybrid nvidia + amd iGPU: nvidia pkgs present, iGPU drives display -> radeonsi
    (expect "hybridAmd.libva"    (libva c.hybridAmd) "radeonsi")
    (expect "hybridAmd.nv"       (has c.hybridAmd "nvidia-vaapi-driver") true)

    # compute stack auto-derivation (per slot, both can be live at once)
    (expect "base.computing"       c.base.mx.hardware.gpu.dedicated.computing "cpu")
    (expect "amd.computing"        c.amdCompute.mx.hardware.gpu.dedicated.computing "rocm")
    (expect "intel.computing"      c.intelCompute.mx.hardware.gpu.dedicated.computing "oneapi")
    (expect "nvidia.computing"     c.nvidiaCompute.mx.hardware.gpu.dedicated.computing "cuda")
    (expect "hybrid.dedicated"     c.hybridCompute.mx.hardware.gpu.dedicated.computing "cuda")
    (expect "hybrid.integrated"    c.hybridCompute.mx.hardware.gpu.integrated.computing "oneapi")
    (expect "hybridAmd.dedicated"  c.hybridAmdCompute.mx.hardware.gpu.dedicated.computing "cuda")
    (expect "hybridAmd.integrated" c.hybridAmdCompute.mx.hardware.gpu.integrated.computing "rocm")
    (expect "igpuOnly.dedicated"   c.igpuOnly.mx.hardware.gpu.dedicated.computing "cpu")
    (expect "igpuOnly.integrated"  c.igpuOnly.mx.hardware.gpu.integrated.computing "rocm")

    # compute side effects
    (expect "amdCompute.opencl"  c.amdCompute.hardware.amdgpu.opencl.enable true)
    (expect "amdCompute.mesa"    (has c.amdCompute "mesa") true)
    (expect "intelCompute.rt"    (has c.intelCompute "intel-compute-runtime") true)
    (expect "nvidiaCompute.none" (has c.nvidiaCompute "intel-compute-runtime") false)
    (expect "igpuOnly.opencl"    c.igpuOnly.hardware.amdgpu.opencl.enable true)

    # hybrid: the iGPU stack is installed even though the dGPU drives CUDA
    (expect "hybridCompute.rt"     (has c.hybridCompute "intel-compute-runtime") true)
    (expect "hybridAmdCompute.ocl" c.hybridAmdCompute.hardware.amdgpu.opencl.enable true)
    (expect "hybridAmdCompute.mesa" (has c.hybridAmdCompute "mesa") true)
    (expect "nvidiaCompute.noOcl"  c.nvidiaCompute.hardware.amdgpu.opencl.enable false)

    # X video drivers: every GPU present gets its driver, dedicated first
    (expect "base.drivers"       (lib.mxGpuVideoDrivers (layout c.base)) [ "modesetting" ])
    (expect "amd.drivers"        (lib.mxGpuVideoDrivers (layout c.amd)) [ "amdgpu" ])
    (expect "intelTiger.drivers" (lib.mxGpuVideoDrivers (layout c.intelTiger)) [ "modesetting" ])
    (expect "nvidia.drivers"     (lib.mxGpuVideoDrivers (layout c.nvidia)) [ "nvidia" ])
    (expect "hybridAmd.drivers"  (lib.mxGpuVideoDrivers (layout c.hybridAmd)) [ "nvidia" "amdgpu" ])
    (expect "hybridIntel.drivers" (lib.mxGpuVideoDrivers (layout c.hybridIntel)) [ "nvidia" "modesetting" ])
    (expect "igpuOnly.drivers"   (lib.mxGpuVideoDrivers (layout c.igpuOnly)) [ "amdgpu" ])

    # primary slot: dedicated wins, integrated is the fallback
    (expect "hybridAmd.primary"  (lib.mxGpuPrimary (layout c.hybridAmd)).vendor "nvidia")
    (expect "igpuOnly.primary"   (lib.mxGpuPrimary (layout c.igpuOnly)).vendor "amd")
    (expect "igpuOnly.primaryGen" (lib.mxGpuPrimary (layout c.igpuOnly)).generation "rdna2")
    (expect "base.primary"       (lib.mxGpuPrimary (layout c.base)).vendor null)

    # integrated launcher: built only when the PCI id is known
    (expect "igpuOnly.noLauncher" (c.igpuOnly.mx.hardware.gpu.integrated.launcher == null) true)
    (expect "igpuLauncher.name"   c.igpuLauncher.mx.hardware.gpu.integrated.launcher.name "igpu-launch")
  ];

  allOk = lib.all (x: x == true) checks;

  check = assert allOk;
    pkgs.runCommand "gpu-eval" { } ''
      echo "gpu-eval: ${toString (lib.length checks)} assertions passed"
      touch $out
    '';
in
{
  inherit results check;
}
