{ writeShellScriptBin
, lib
, igpuId
, igpuNumber ? 1
, pciAddr ? null
}:

let
  driPci = "pci-0000_" + (lib.replaceStrings [ ":" "." ] [ "_" "_" ] pciAddr);
in
writeShellScriptBin "igpu-launch" ''
  export MESA_VK_DEVICE_SELECT="${igpuId}!"
  ${lib.optionalString (pciAddr != null) "export DRI_PRIME=${driPci}"}

  gpu_count="$(find /sys/class/drm -maxdepth 1 -name 'card[0-9]*' | grep -cE '/card[0-9]+$')"
  if [ "$gpu_count" -gt 1 ]; then
    export MANGOHUD_CONFIG="$(echo "$MANGOHUD_CONFIG" | sed 's/gpu_list=[^,]*/gpu_list=${toString igpuNumber}/' || echo "$MANGOHUD_CONFIG")"
  else
    export MANGOHUD_CONFIG="$(echo "$MANGOHUD_CONFIG" | sed -E 's/(^|,)gpu_list=[^,]*//' | sed -E 's/^,//')"
  fi

  exec "$@"
''
