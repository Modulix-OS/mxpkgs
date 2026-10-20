# DaVinci Resolve on ModulixOS

Covers `mx.programs.studio.davinci-resolve` (free edition) and
`mx.programs.studio.davinci-resolve-studio`. The two are mutually exclusive: the
free module disables itself when the Studio one is enabled.

## 1. Codecs — what the free edition cannot read

The free edition of Resolve ships **no H.264, H.265 or AAC licence on Linux**. The
only decode path left for those formats is NVDEC, which requires an NVIDIA GPU, so
on an AMD or Intel machine a `.mp4` shot by a phone or a camera lands in the
timeline as offline media with silent audio. The log makes it explicit:

```
IO.Audio | ERROR | Failed to decode clip </path/to/clip.mp4>, track: 0, position: 0
         | - Failed to decode the audio samples.
```

Nothing can be configured away here. Resolve decodes with its own bundled
libraries, not with the system ffmpeg or GStreamer, so installing codecs system-wide
has no effect.

Two ways out:

- **Transcode the footage** to an edit-friendly intermediate:

  ```sh
  ffmpeg -i rush.mp4 -c:v dnxhd -profile:v dnxhr_hq -pix_fmt yuv422p \
         -c:a pcm_s16le rush.mov
  ```

  DNxHR HQ in a `.mov` with PCM audio reads natively on every edition. ProRes 422
  works too. Expect roughly 5 to 10 times the file size of the H.264 original.

  The free module ships `mx-mp4-to-mov`, a Zenity front-end for exactly this
  command, listed in the launcher as *MP4 to MOV*. It opens on an intro window
  titled *Convert MP4 to MOV* with a *Browse* button, then lists what you picked;
  the output folder is asked for when you press *Convert*. The nominal path is six
  windows: intro, file chooser, list, folder chooser, progress, summary.

  The output format is DNxHR HQ unless you change it with the *Format* button, which
  keeps it off the nominal path:

  | Preset | ffmpeg | Note |
  |---|---|---|
  | DNxHR HQ | `-c:v dnxhd -profile:v dnxhr_hq -pix_fmt yuv422p -c:a pcm_s16le` | default |
  | DNxHR SQ | `-profile:v dnxhr_sq` instead | smaller files |
  | ProRes 422 | `-c:v prores_ks -profile:v 2 -pix_fmt yuv422p10le -c:a pcm_s16le` | |
  | Container only | `-c copy -movflags +faststart` | keeps H.264, so it stays **unreadable** on the free edition |

  Existing files are never overwritten: a `-1`, `-2` suffix is appended instead.
  Cancelling the progress dialog kills the running ffmpeg and deletes the partial
  `.mov`. When a file fails, the ffmpeg log is shown instead of the summary.

  Two details worth knowing, both there to keep dialogues from piling up. The
  progress bar is capped at 99 % until the last file is muxed, because `--auto-close`
  would otherwise fire while ffmpeg is still writing the trailer and the script would
  read that as a cancellation. And the two dialogue loops carry a spin guard: more
  than twelve iterations within four seconds aborts with
  `dialogue loop detected`, rather than spraying windows across the screen. Setting
  `MX_MP4_TO_MOV_TRACE=/tmp/mov.log` appends one line per dialogue opened, which is
  the way to find out what is being opened and why.

  The interface follows the session locale for English, French, Spanish and German,
  and falls back to English otherwise; `MX_MP4_TO_MOV_LANG=fr` forces it.

- **Use Resolve Studio** (`mx.programs.studio.davinci-resolve-studio`), which
  licences H.264, H.265 and AAC. The module also installs the udev rule the
  Blackmagic USB licence dongle needs.

Formats that read natively on both editions: DNxHR, ProRes, Blackmagic RAW,
CinemaDNG, R3D, ARRIRAW, and uncompressed or PCM audio.

## 2. Hybrid laptops — starting on the discrete GPU

Resolve draws its UI with OpenGL and shares buffers with its OpenCL compute device.
When the UI starts on the iGPU while the compute board manager targets the discrete
card, the cross-device buffer sharing fails at startup:

```
UI.GLContext      | Initialized OpenGL 4.6 on device 'AMD Radeon 780M Graphics (radeonsi, phoenix…)'
GPU.MultiBoardMgr | Initializing OpenCL board manager for Main Display GPU gpu:aecdd0cb…
DVIP              | ERROR | Failed to create OpenCL context:
                  | DVIP Exception: OpenCL Context Manager failed to create context.
GPU.MultiBoardMgr | ERROR | Failed to initialize board manager for gpu:aecdd0cb…
```

Both Resolve modules therefore ship a `.desktop` override carrying
`PrefersNonDefaultGPU=true`, installed at `lib.hiPrio` so it wins over the one from
the package. That key is inert on its own: it needs `switcheroo-control`, which
`mx.hardware.gpu.hybrid.enable` turns on. That option defaults to `true` as soon as
both `mx.hardware.gpu.dedicated.vendor` and `mx.hardware.gpu.integrated.vendor` are
set, so declaring both GPU slots is what makes the fix apply — see
[`hardware-gpu.md`](hardware-gpu.md).

`switcheroo-control` reads `boot_vga` from sysfs to tell the default GPU from the
discrete one, so a desktop whose discrete card already drives the display is left
alone.

Consequences worth knowing:

- The routing happens in the **desktop launcher**. Running `davinci-resolve` from a
  terminal bypasses it and starts on whatever GPU the session defaults to.
- A per-user override may already be pinned in
  `~/.local/share/DaVinciResolve/configs/config.dat` under `Local.GPU.Mapping`.
  Resolve honours it over everything else; remove the line to fall back to the
  automatic selection.
- Resolve's own automatic compute selection compares reported memory, and an APU
  reports its GTT size (often larger than the discrete card's VRAM). If it still
  picks the iGPU after the UI starts on the discrete card, pin the right GPU in
  *Preferences → Memory and GPU → GPU selection → Manual*.

### Why the GPU list used to show every board twice

*Preferences → Memory and GPU → GPU selection* lists one entry per OpenCL device
**per ICD**, not per physical GPU. With both the ROCm ICD (`amdocl64.icd`) and the
Mesa one (`rusticl.icd`) installed, a hybrid AMD laptop showed four entries for two
boards — the rusticl ones recognisable by their suffix:

```
AMD Radeon 780M Graphics                                             15,3 GB
AMD Radeon RX 7700S                                                   8,0 GB
AMD Radeon 780M Graphics (radeonsi, phoenix, ACO, DRM 3.64, …)       15,8 GB
AMD Radeon RX 7700S (radeonsi, navi33, ACO, DRM 3.64, …)              8,0 GB
```

Resolve wants the ROCm runtime; rusticl is not a path it supports. So
`mx.hardware.gpu.compute.rusticl.enable` defaults to `false` and only `amdocl64.icd`
is installed. Confirm with:

```sh
ls /run/opengl-driver/etc/OpenCL/vendors/   # amdocl64.icd alone
clinfo -l                                   # one platform
```

Check the result in `~/.local/share/DaVinciResolve/logs/ResolveDebug.txt`:

```
UI.GLContext | Initialized OpenGL 4.6 … on device 'AMD Radeon RX 7700S (radeonsi, navi33…)'
UI.GLIO      | Initialized MainPlayer OpenGL I/O on OpenCL device 'gfx1102'
```

## 3. Wayland

Resolve bundles its own Qt and does not run on a native Wayland session (qtwayland
version mismatch, NixOS/nixpkgs#341634). `GPUDetect | WARN | X11 logs not found.` in
the log is the tell. Launch it under XWayland if the UI misbehaves:

```sh
QT_QPA_PLATFORM=xcb davinci-resolve
```

## 4. OpenFX plugins

`/usr/OFX/Plugins` does not exist on NixOS, so plugin packages go through the module
instead; paths are traversed recursively, pointing at the package root is enough:

```nix
mx.programs.studio.davinci-resolve.ofxPlugins = [ pkgs.some-ofx-plugin ];
```

This sets `OFX_PLUGIN_PATH` system-wide.
