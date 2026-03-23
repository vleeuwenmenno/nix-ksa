# nix-ksa

Nix flake to install and run [Kitten Space Agency](https://ksa-linux.ahwoo.com) (KSA) on NixOS / Nix.

> **KSA is in VERY ALPHA** — expect bugs, crashes, and missing features.

## Requirements

- Nix with flakes enabled
- x86_64-linux
- A Vulkan-capable GPU

## Usage

Run directly:

```bash
nix run github:vleeuwenmenno/nix-ksa
```

Or from a local checkout:

```bash
nix run .
```

## Wayland note

The wrapper defaults to `GLFW_PLATFORM=x11` (XWayland) because native Wayland has issues with GLFW 3.5 on tiling compositors like Hyprland (missing window decorations, broken scroll, fullscreen glitches).

To try native Wayland:

```bash
GLFW_PLATFORM=wayland nix run .
```

## What the flake does

KSA ships as a self-contained tarball with a .NET 10 apphost and bundled native libraries (GLFW, FMOD, ImGui, shaderc, etc.). This flake:

- Fetches the official tarball from `ksa-linux.ahwoo.com`
- Patches ELF binaries via `autoPatchelfHook` (fixes interpreter, RPATH)
- Provides .NET 10 runtime via `DOTNET_ROOT`
- Injects runtime library paths for Vulkan, X11, Wayland, audio (ALSA/PulseAudio), ICU, and libdecor

## Updating

When a new version is released, update `version` and `hash` in `flake.nix`:

```bash
# Download the new tarball and compute its hash
nix hash file --type sha256 --to sri setup_ksa_vNEW_VERSION.tar.gz
```

## Known issues

- **Fullscreen doesn't render correctly on startup** — the game starts in fullscreen but nothing displays until you switch to windowed mode. Observed on Hyprland (NixOS), unclear if this affects other Wayland compositors or XWayland-only setups.
- **Scroll only zooms out, not in** — mouse scroll input only registers in one direction. Also observed on Hyprland; may be a GLFW/XWayland interaction issue or an upstream KSA bug.
- **Native Wayland is broken** — GLFW 3.5's Wayland backend produces `The platform does not provide the window position` errors and the window never appears on tiling compositors. The wrapper defaults to XWayland (`GLFW_PLATFORM=x11`) as a workaround.

> These issues were observed on NixOS with Hyprland. They may or may not be specific to Hyprland — testing on other compositors (Sway, GNOME, KDE) would help narrow it down. KSA is in very early alpha so some of these may be upstream bugs.

## License

The flake packaging is MIT. KSA itself is proprietary (unfree).
