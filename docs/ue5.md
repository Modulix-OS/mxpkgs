# Unreal Engine 5 on ModulixOS

Covers `mx.programs.dev.ue5`. The module installs a launcher, not the engine: Epic
does not allow redistributing the Linux editor, so the binaries are fetched by the
user and extracted on first run. Everything else — the container, its dependencies,
the desktop entry, the `.uproject` association — is handled by the module.

## 1. Getting the archive

The editor comes from <https://www.unrealengine.com/linux>, as a `.zip` of a
few dozen gigabytes. It requires an Epic Games account, and the download page asks
for the **prebuilt Linux version**, not the source tree: the source needs
`Setup.sh`, `GenerateProjectFiles.sh` and a full build before anything runs, which
the launcher does not do.

The archive is checked before extraction by looking for `Engine/` in its table of
contents. A file that does not match raises a question dialogue rather than an
error, so an unusual but valid archive can still be installed.

## 2. What the first launch does

Clicking *Unreal Engine 5* in the application grid runs `mx-ue5`, which walks
through, in order:

1. A file chooser for the `.zip`, and the `Engine/` check on its table of
   contents. Nothing is downloaded or created before this: cancelling here leaves
   the machine exactly as it was.
2. A free-space check. `unzip -l` gives the archive's uncompressed size, `df` the
   space left on the install directory's filesystem, and the install refuses to
   start unless the second covers the first plus 5 GiB of headroom. A reinstall
   counts the space the current install will give back, so replacing an engine in
   place does not get refused for lack of room it is about to free.
3. `podman pull` of `docker.io/library/ubuntu:26.04`, with a progress window. Only
   on first run — later launches skip straight to the editor.
4. `distrobox create` of the container **`distrobox-app-ue5`**, dedicated to the
   engine and separate from the `ubuntu` container of
   `mx.programs.dev.distrobox`. Shared home directory, so the extracted engine and
   your projects are the same files inside and outside.
5. Removal of a previous install, when there is one. `unzip -o` overwrites but
   never deletes, so extracting 5.7 over 5.4 would otherwise leave the plugins and
   `.so` files the new release dropped, and the editor would still load them. Only
   the engine's own entries go; the `.mx-ue5-*` markers stay, which is what keeps
   the container from being rebuilt for nothing.
6. Extraction into `mx.programs.dev.ue5.installDir`
   (`$HOME/.local/share/ue5` by default), with a real percentage: the entry count
   from `unzip -l` is the denominator, the lines `unzip` prints as it goes are the
   numerator. Some Epic archives wrap everything in a `UnrealEngine-5.x.x/` folder;
   that level is flattened away when it is there.
7. `apt-get install` of the editor's runtime dependencies inside the container —
   Mesa and Vulkan, X11, SDL, ALSA and PulseAudio, the GTK stack, and ICU.
8. `Setup.sh` if the archive ships one. The prebuilt release has none, and the step
   is then skipped outright rather than flashing an empty progress window.

Every step reports its own failure by name, and points at the log described below.

A marker file `.mx-ue5-installed` in the install directory is what separates the
two states. Delete it and the next launch reinstalls from an archive; the container
is reused if it still exists. *Reinstall* in the launcher menu does the same thing
without the file manager.

A third marker, `.mx-ue5-incomplete`, exists only while the steps are running.
Closing the progress window mid-extraction kills `unzip` and leaves a half-written
engine behind; the marker survives it, and the next run wipes the directory before
extracting rather than merging a new archive into the wreck.

Only one installer window can be open at a time. The launcher takes an `flock` on
`$XDG_RUNTIME_DIR/mx-ue5.lock` and tells the second one to go away, so two clicks
on the icon cannot have two `unzip` runs writing the same tree. The lock is
released before the editor starts, so running several editors at once still works.

### The install log

Steps write nothing to the screen. Their standard output and standard error go to

```
~/.local/state/mx-ue5/install.log
```

and only a percentage or a pulse reaches the progress window, over file descriptor
3. Every failure dialogue names that file. The log is appended to, with a dated
header per run, and truncated once it passes 1 MiB.

The container is disposable, the extracted engine is not. A second marker,
`.mx-ue5-image`, records the image the container was built from. When it no longer
matches `mx.programs.dev.ue5.image` — or when the container has been deleted by
hand — the next launch rebuilds the container and replays the dependency step
alone, leaving the tens of gigabytes already on disk untouched. Changing the Ubuntu
release therefore costs a few minutes, not another download from Epic.

The image the container is replaced from is removed afterwards, so abandoned
releases do not accumulate at roughly 160 MB each. The stamp records the image id
next to its name, and removal goes by id, so a tag that has been repointed since
leaves nothing untagged behind either.

## 3. Why Ubuntu 26.04

`mx.programs.dev.ue5.image` defaults to `docker.io/library/ubuntu:26.04`, and the
reason is the graphics driver rather than the distribution. The editor draws with
Vulkan and loads its driver from inside the container, so the release pinned here
is the one that decides which Mesa the engine runs on — the host's Mesa is never
used. Ubuntu 26.04 carries Mesa 26.0, which is what the editor asks for. On 22.04,
whose Mesa is 23.2, the editor opens a *Known issues with graphics driver* dialogue
on RDNA 3 and newer AMD cards, naming the container's version:

```
AMD Unknown (RADV GFX1102)
Installed: 23.2.1
Recommended: 26.0.0 or latest driver available
```

The version is pinned rather than left on `latest` because the dependency list the
installer runs is written against these package names, and several moved across
releases — `libasound2` is `libasound2t64` from 24.04 on. `apt-get install`
installs *nothing at all* when one name on the line does not resolve, so a single
bulk command on a floating tag would eventually fail the whole step.

So the step does not rely on the bulk command succeeding. It tries the whole list
at once, and on failure falls back to installing package by package, collecting the
names that did not resolve. Only a short critical list — `libvulkan1`,
`mesa-vulkan-drivers`, `libgl1-mesa-dri`, `libglu1-mesa`, `libsdl2-2.0-0`,
`libx11-6`, `libssl3`, `ca-certificates` — fails the step; anything else is logged
as skipped and the install carries on. Setting `image` to a release older than
24.04 also raises a build-time warning, since the Mesa problem above remains
whatever apt manages to install.

The list carries no Mono and no system .NET. The prebuilt editor ships its own
runtime in `Engine/Binaries/ThirdParty/DotNet/`, and modern Unreal has no Mono
directory at all, so those packages were only pinning the image to older releases
that still had them.

It does carry ICU, which that bundled runtime does need. .NET aborts with
`Couldn't find a valid ICU package installed on the system` when it is missing, and
the Ubuntu base image does not ship it — so UnrealBuildTool, project generation and
`RunUAT.sh` would all fail while the editor itself started fine. The package name
is versioned and moves every release (`libicu74`, `libicu76`, …), which is exactly
the pinning trap described above, so the step resolves it at install time with
`apt-cache --names-only search '^libicu[0-9]+$'` and takes the highest version
rather than hardcoding one.

`apt-get clean` and the removal of `/var/lib/apt/lists` close the step. The
container is persistent, and nothing would ever evict that cache on its own.

The name is fully qualified on purpose. NixOS writes two unqualified search
registries into `/etc/containers/registries.conf`, and podman stops on an
interactive menu when a short name is ambiguous — which a launcher started from a
desktop entry can never answer.

## 4. GPU

`mx.programs.dev.ue5.nvidia` passes `--nvidia` to `distrobox create`, bind mounting
the host driver into the container, and switches on
`hardware.nvidia-container-toolkit`. It defaults to on when
`mx.hardware.gpu.dedicated.vendor` is `nvidia` and the card is not disabled; the
flag fails outright on a machine without an NVIDIA GPU, which is why it is not
unconditional.

On AMD and Intel the container reaches the GPU through the host `/dev/dri` nodes
that distrobox already shares, with `mesa-vulkan-drivers` installed on the Ubuntu
side.

On a hybrid laptop — both GPU slots declaring a vendor, so
`mx.hardware.gpu.hybrid.enable` is true — the desktop entry carries
`PrefersNonDefaultGPU=true` and the editor starts on the discrete card, the same
mechanism `lib/prefers-dgpu-desktop.nix` applies to DaVinci Resolve. The launcher
deliberately sets no `DRI_PRIME` of its own: switcheroo-control exports the
offload variables into the process the desktop entry starts, `distrobox enter`
carries them into the container, and a hardcoded value would override the choice
the desktop just made.

The container is created once. Changing `nvidia` afterwards has no effect until it
is recreated — uninstall from the launcher menu, then install again.

## 5. Day-to-day use

- Clicking the icon with the engine installed opens a three-item menu: *Launch*,
  *Reinstall from an archive* or *Uninstall*. *Reinstall* is the upgrade path: it
  asks for a new `.zip`, wipes the engine files and extracts over them, and keeps
  the container — so moving from 5.5 to 5.7 does not cost another `podman pull`
  and another `apt-get` round.
- Double-clicking a `.uproject` opens it directly in the editor. The module ships
  the `application/x-ue-project` MIME type, since no shared-mime-info package
  defines it. A `.uproject` outside the home directory raises a warning first: the
  home directory is the only one the container shares with the host, so a project
  on an external disk mounted under `/run/media` has no path inside the container
  and the editor would simply not find it.
- `mx-ue5-shell` drops into a shell in `distrobox-app-ue5`, which is where `apt`,
  `clang` and the engine's own `RunUAT.sh` belong. Packaging a project runs inside
  the container, never on the host.
- Extra build tooling belongs in `mx.programs.dev.ue5.additionalPackages`; it is
  handed to `distrobox create`, so it only takes effect on a container that does
  not exist yet.
- The interface follows the session locale for English, French, Spanish and German,
  and falls back to English otherwise; `MX_UE5_LANG=fr` forces it. `mx-ue5 --help`
  describes the rest.

## 6. Uninstalling

*Uninstall* in the launcher menu removes the `distrobox-app-ue5` container, the
Ubuntu image it was built from, everything in the install directory and the state
directory holding the install log, after a confirmation. Nothing is left in podman
storage. The deletion of the install directory refuses to run on a path that is
empty, relative, `/` or the home directory itself — the same guard the reinstall
path runs before it wipes anything.

The image is removed by the id recorded in `.mx-ue5-image` rather than by name, so
an image whose tag has moved on since — `ubuntu:26.04` repointed by a later pull,
for instance — is still cleaned up instead of being left behind untagged. Podman
refuses to delete an image while a container still uses it, and that refusal is
ignored rather than treated as an error, which is what keeps an image shared with
`mx.programs.dev.distrobox` in place.

The desktop entry stays — it belongs to the Nix store, not to the install — so
clicking the icon again restarts the wizard. Removing the entry means setting
`mx.programs.dev.ue5.enable = false` and rebuilding.
