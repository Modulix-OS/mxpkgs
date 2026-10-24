{ lib
, symlinkJoin
, writeShellScript
, blender
, rocmLLVM ? null
, gpuBackend ? null
}:

let
  blenderBin = "${blender}/bin/blender";

  script = writeShellScript "mx-blender" ''
    set -e
    ${lib.optionalString (rocmLLVM != null) ''
      export LD_PRELOAD="${rocmLLVM}/lib/libLLVM.so''${LD_PRELOAD:+:$LD_PRELOAD}"
    ''}
    ${
      if gpuBackend == null then
        ''
          exec "${blenderBin}" "$@"
        ''
      else
        ''
          for arg in "$@"; do
            case "$arg" in
              --gpu-backend|--gpu-backend=*) exec "${blenderBin}" "$@" ;;
            esac
          done
          exec "${blenderBin}" --gpu-backend ${gpuBackend} "$@"
        ''
    }
  '';
in
symlinkJoin {
  name = "mx-blender-${blender.version}";
  paths = [ blender ];

  postBuild = ''
    rm -f $out/bin/blender
    install -Dm755 ${script} $out/bin/blender
  '';

  meta = blender.meta // {
    mainProgram = "blender";
  };

  passthru = (blender.passthru or { }) // {
    unwrapped = blender;
    inherit rocmLLVM gpuBackend;
  };
}
