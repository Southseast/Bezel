# Bezel

English | [简体中文](README.md)

A tiny macOS tool that melts the notch into the menu bar: a full-width pure
black band sits right below the system menu bar, so its translucent material
samples pure black — the whole menu bar turns black and the notch becomes just
part of the bezel.

## Why

[TopNotch](https://topnotch.app/) no longer works on recent macOS releases, so
this is a fresh take. Unlike TopNotch's wallpaper-rewriting approach, Bezel
uses an overlay window right below the menu bar: **no wallpaper is modified,
toggles instantly, reverts on quit, public APIs only**.

## Features

- Full-width black menu bar; the notch blends in seamlessly (real notch height
  via safe area insets, fallback for non-notch displays)
- Persists across desktop spaces; multiple displays supported (built-in only
  optional)
- Lives in the background: syncs automatically on display and setting changes
- Optional: fill the rounded corners of your screen
- Optional: fade animation
- Hides automatically over fullscreen apps (nothing to tint there)
- Launch at login (SMAppService)
- English / Simplified Chinese UI, follows the system language

## Known limitations

- During animated Cmd+Tab space switches the window server briefly detaches
  floating-level windows, so the bar can blink for the duration of the
  transition (~0.3 s) — a WindowServer behavior that public APIs cannot avoid.
- macOS 26 app window corner radii are inconsistent, so the rounded corner
  fill can leave small gaps at some window corners; verified fine on macOS 27.

## Build & run

```bash
./make.sh
open build/Bezel.app
```

Requires macOS 14+ and Swift 5.9+. The app is a menu bar agent (no Dock
icon):

- **Click the status item** (left or right): opens the menu with all settings
- Checkable items: enable, built-in displays only, rounded corners, fade
  animation, launch at login
- No separate settings window; toggles apply instantly

## Versioning & releases

- Versions are driven by git tags: after tagging (`git tag v0.2.0`) a rebuild
  embeds the version automatically; untagged trees build as `0.1.0-dev` with
  the commit hash
- `./make.sh zip` produces a `dist/Bezel-<version>.zip` release package
- Once the repo is on GitHub, pushing a `v*` tag triggers GitHub Actions to
  build and attach the zip to a Release (see `.github/workflows/release.yml`)
- Distribution note: the app is ad-hoc signed; after downloading, right-click
  → Open on first launch, or run `xattr -cr /path/to/Bezel.app`

## Implementation notes

- One transparent full-screen `NSPanel` per targeted display at
  `.mainMenu - 1` (below the menu bar, above app windows); mouse events pass
  through.
- Only the drawn band commits physical memory — the bar costs ~6 MB and the
  whole app idles at ~21 MB. Reproduce with `./measure-memory.sh` (automatic
  A/B measurement, restores your setting).
- Display and setting changes trigger rebuild/recycle; disabling fades the
  windows out and closes them for good.
- Replace `Assets/Bezel.png` and run `python3 Assets/build-icns.py` to
  regenerate the app icon (losslessly optimized).
