{ lib }:
let
  gpuStacks = gpu:
    lib.unique (lib.filter (s: s != "cpu") [
      gpu.dedicated.computing
      gpu.integrated.computing
    ]);

  driverFor = vendor:
    if vendor == "amd" then "amdgpu"
    else if vendor == "nvidia" then "nvidia"
    else "modesetting";

  presentSlots = gpu: lib.filter (slot: slot.vendor != null) [ gpu.dedicated gpu.integrated ];
in
{
  mxGpuStacks = gpuStacks;

  mxGpuHasStack = gpu: stack: builtins.elem stack (gpuStacks gpu);

  mxGpuPrimary = gpu: if gpu.dedicated.vendor != null then gpu.dedicated else gpu.integrated;

  mxGpuVideoDrivers = gpu:
    let
      present = presentSlots gpu;
    in
      if present == [ ]
      then [ "modesetting" ]
      else lib.unique (map (slot: driverFor slot.vendor) present);
}
