# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A [Quickshell](https://quickshell.org) (QML/Qt6, Hyprland-focused Wayland shell toolkit) configuration providing a top status bar and a macOS-style auto-hiding dock, styled in Catppuccin Mocha. Quickshell version installed: 0.3.1 (`quickshell --version`). This is not a compiled project — there is no build step; QML is interpreted at launch.

Companion configs referenced by this one, for context on the wider desktop:
- `~/.config/hypr/hyprland.lua` — Hyprland config (native Lua, **not** stock hyprlang). Window class rules (`floaters` table), keybinds, autostart (`hl.on("hyprland.start", ...)`), and layer-shell blur rules (`hl.layer_rule`) all live here. The bar's blur rule (`blur-quickshell`, namespace `"quickshell"`, `ignore_alpha = 0.15`) is defined there, not in this repo.
- `~/.config/waybar/` — an older waybar config this bar was modeled on/replaces (Catppuccin palette, module set, floating-pill aesthetic). Not used if this shell is running instead.

## Running / testing

There's no test suite. "Testing" means launching the shell against the live Hyprland session and inspecting behavior.

```bash
quickshell -p /home/schultzh/.config/quickshell/shell.qml   # foreground; Ctrl-C to stop
# or, since this IS ~/.config/quickshell/shell.qml, the "default" config:
qs                                                            # equivalent shorthand
```

- **Syntax/type-check without watching it run**: `timeout 5 quickshell -p .../shell.qml` and read stdout — it prints `INFO: Configuration Loaded` on success, or `ERROR:`/`WARN:` lines (QML parse errors, binding loops, deprecation notices) on problems. This is fast and doesn't require a display.
- **Editing while a real instance is running**: quickshell hot-reloads on file save (`INFO: Reloading configuration...` appears in its output). No restart needed for most changes; a full kill+relaunch is only needed after editing `pragma` lines (`UseQApplication`, `IconTheme`) at the top of `shell.qml`, since those are process-start-time flags.
- **Runtime logs**: each run gets a fresh dir at `/run/user/1000/quickshell/by-id/<id>/` with `log.qslog` (binary) and `log.log` (readable). `quickshell ipc show` lists live IPC targets from a running instance if you need to check one is up.
- **Reload Hyprland itself** (needed after editing `hyprland.lua`, e.g. layer rules or the autostart block): `hyprctl reload`.

### The IPC trick for interactive testing

Real mouse/cursor testing is unreliable here — this Hyprland build's `hl.dsp.cursor.move({x=..,y=..})` does not reliably land at the requested coordinates (confirmed by checking `hyprctl cursorpos` against the request), so treat any test built on synthetic cursor placement as suspect. **The reliable technique used throughout this config's development**: temporarily add an `IpcHandler { target: "somename"; function foo(arg: string): string { ...; return "result"; } }` block (needs `import Quickshell.Io`) exposing whatever internal state/action you need to poke, then drive it from the shell:

```bash
quickshell ipc call somename foo bar
```

This lets you flip properties, call functions, and read back computed state directly — far more precise than screenshots or cursor simulation. **Always remove the IpcHandler (and the now-unneeded `Quickshell.Io` import) before considering a change finished** — none should ship in the committed config. Grep for `IpcHandler` before wrapping up if unsure one wasn't left behind.

Two IPC targets exist per dock instance, named `dockdebug_<screenName>` with hyphens replaced by underscores (e.g. `dockdebug_DP_2`) specifically so multiple monitor instances don't collide on the same target name — follow that convention if re-adding debug handlers to a per-screen component.

Screenshots (`grim -o <output> file.png`, outputs named via `hyprctl monitors -j`) are the fallback for visual-only concerns (colors, spacing, icon rendering) but are comparatively expensive: cross-monitor combined screenshots (`grim` with no `-o`) are scaled by some ratio that is **not** any single monitor's DPI scale, so pixel math against them is unreliable — always screenshot one output at a time with `-o` when precision matters.

## Architecture

### Two independent top-level surfaces, both per-monitor

`shell.qml` is the entry point. It defines two `Variants { model: Quickshell.screens }` blocks, each instantiating one `PanelWindow` per connected monitor:
1. **Bar** (`Bar.qml`) — top-anchored, on every screen.
2. **Dock** (`Dock.qml`) — bottom-anchored, on every screen (was DP-2-only earlier in development; now mirrors Bar's per-screen pattern). Pin state is shared across monitors via the `DockPins` singleton, not duplicated per instance.

Both follow the same wlr-layer-shell sizing trick (see "Surfaces can't paint outside their own buffer" below): the actual `PanelWindow` is taller/wider than the visible content, with `exclusiveZone` set to just the visible portion and an explicit `mask: Region { item: someFixedSizeItem }` restricting the *input* region to match — the extra space is for visual overflow only (tooltips, magnified dock icons), and is deliberately excluded from the mask so it stays click-through.

### Singletons (`pragma Singleton`, registered in `qmldir`)

- **`Theme`** — Catppuccin Mocha palette + all layout constants (sizes, spacing, animation durations/easings) for both Bar and Dock. Any new module should pull constants from here rather than hardcoding.
- **`SysStats`** — polls `scripts/sysstats.sh` every 2s via `Quickshell.Io.Process`, exposes CPU/mem/temp/network as reactive properties plus rolling history arrays for the bar's sparkline graphs. One instance serves both monitors' bars.
- **`DockPins`** — the dock's pinned-apps list and its persistence to `dock-pins.json` (via `FileView`). Shared by every monitor's `Dock` instance so pinning/unpinning from either stays in sync everywhere; `Dock.qml` itself holds no pin state, only `dockEntries` (which it rebuilds locally from `DockPins.pinnedApps` + live `Hyprland.toplevels`).

Files in `modules/` are plain (non-singleton) components; the root directory's `qmldir` only lists the singletons plus `Bar`/`Dock` themselves — everything in `modules/` resolves via QML's implicit same-directory import, importable from the root as `import "./modules" as Modules`.

### Bar module pattern

Every right-side/left-side bar item (`Cpu`, `Memory`, `Volume`, `Battery`, `Network`, `WindowTitle`, `ClockTime`, `ClockDate`, `Tray`'s icons) wraps `modules/Pill.qml`, which provides: hover background, click/right-click/wheel signals, a `tooltipText` property with an auto-showing/hiding tooltip, and a `Behavior`-animated `implicitWidth`. `Pill`'s content area has `clip: true` specifically so a growing pill (e.g. `WindowTitle` on a longer title) reveals new content through the expanding pill rather than the text spilling outside a still-animating background.

Data sources for bar modules, by module:
- `Workspaces`, `WindowTitle` — live `Quickshell.Hyprland` bindings (`Hyprland.workspaces`, `Hyprland.monitors`, per-monitor `activeWorkspace.toplevels`), no polling.
- `Cpu`, `Memory`, `Temperature`, `Network` — `SysStats` singleton (polled).
- `Volume` — `Quickshell.Services.Pipewire` (`Pipewire.defaultAudioSink`, needs a `PwObjectTracker` to bind it before `.audio.volume/.muted` are valid).
- `Battery` — `Quickshell.Services.UPower` (`UPower.displayDevice`) — event-driven, not polled. **`UPowerDevice.percentage` is a 0–1 fraction, not 0–100** — multiply by 100.
- `Tray` — `Quickshell.Services.SystemTray`, icons via `Quickshell.Widgets.IconImage`.

### Dock architecture

`Dock.qml` (root, one per screen) owns:
- `dockEntries` — rebuilt (`rebuildEntries()`) whenever `Hyprland.toplevels` or `DockPins.pinnedApps` change. Merges pinned apps (resolved via `DesktopEntries.byId`/`heuristicLookup`, or a custom `exec` launcher for apps with no `.desktop` file — see the Yazi entry in `DockPins.defaultPinnedApps`) with any other running, unpinned app.
- **Window→group-key mapping** (`effectiveGroupKey`) is not a straight class match: `kitty-float` folds into the plain `kitty` group, and any window (regardless of class) titled `Yazi: ...` groups under the dedicated Yazi entry. Extend this function, not the matching in `rebuildEntries`, when adding similar aliasing.
- **Magnification math** (`magnifyFor`, `magnifyBudget`, `hoveredRowWidth`): icons don't magnify independently off a raw falloff curve — there's one *fixed* growth budget (worth exactly one icon's max growth) redistributed across nearby icons proportional to cursor-distance weight, so the row's total content width is a mathematical constant regardless of cursor position (verified: identical sum at every sampled cursor position). This was a deliberate fix for visible "bounce" from a live-recalculated width; don't reintroduce per-position width variation. `contextMenuIndex` (see below) bypasses this budget-sharing to force one icon to exactly `Theme.dockMaxScale` — the two can theoretically double up if the user also hovers a different icon while a menu is open (minor known edge case, not fixed).
- **Height is intentionally fixed** (`restHeight`, sized for resting icons only) — magnified icons overflow past the pill's top edge rather than the pill growing to contain them (macOS-style). `hitHeight` (taller, covers max magnification) is a *separate* value used only for the input/hover hit-region and the window-overlap check, never for the drawn background.
- **Auto-hide** (`windowOverlaps`, `shown`, `pendingHide`): hides only when a real window on the active workspace geometrically overlaps the dock's footprint (checked every 400ms via `Hyprland.refreshToplevels()` + `updateOverlap()`), not unconditionally. A 250ms `pendingHide` grace timer avoids flicker on brief mouse-out. `shown` is also forced true while a context menu is open (`contextMenuEntry !== null`), since moving the mouse onto the menu — a separate popup window — would otherwise register as leaving the dock.
- **Hit region** (`restArea`): full dock size while shown, shrunk to a `Theme.dockRevealStripHeight`-tall strip at the bottom edge while hidden, so the hidden dock isn't eating a large invisible click-blocking chunk of the screen. This is also literally the item the window's `mask: Region` is bound to.
- **Right-click menu** (`modules/DockContextMenu.qml`) is a `PopupWindow`, not embedded in the dock's own surface, so it can be any height. Opening it also forces that icon to full magnification via `contextMenuIndex` so it's visually obvious which icon owns the open menu, even after the mouse leaves the dock entirely for the menu.

## Hard-won gotchas (read before touching geometry/positioning code)

- **wlr-layer-shell surfaces cannot paint outside their own buffer.** Anything meant to visually overflow a panel (tooltips, magnified dock icons) requires the *window* to be sized larger than the visible content, with `exclusiveZone` and an explicit `mask: Region {}` covering only the actually-interactive part. Search for `Theme.tooltipReserve` / `Theme.dockHorizontalHeadroom` for the established pattern before adding a new kind of overflow.
- **`HyprlandMonitor.width`/`height` are physical pixels; window geometry (`HyprlandToplevel.lastIpcObject.at`/`size`) is logical (scale-adjusted).** `HyprlandMonitor.x`/`y` (global layout offsets) are already logical, matching window geometry. On a 1.0-scale monitor this distinction is invisible (physical == logical); it caused a real bug where the dock never auto-hid on the laptop's own scaled panel (`eDP-1`, scale ≈1.667) while working fine on the external 1.0-scale monitor. Any geometry math mixing monitor dimensions with window positions must divide monitor width/height by `hyprMonitor.scale` first (see `Dock.qml`'s `updateOverlap()`).
- **This Hyprland build takes Lua-eval dispatch syntax, not plain-text.** Every `hyprctl dispatch` call (and `Hyprland.dispatch(...)` from QML) must use `hl.dsp.<name>({ ...kwargs })` form (e.g. `hl.dsp.focus({ workspace = 3 })`), never the stock `"workspace 3"` string — the latter is rejected. This is a property of the user's `hyprland.lua`, not of Quickshell.
- **`PopupAnchor`'s `window` and `item` properties fight each other depending on assignment order**: setting `.window` internally clears `.item` (it calls `setItem(nullptr)`), but setting `.item` alone auto-resolves the window non-destructively. Prefer setting `anchor.item` only; if both are needed, set `.window` *before* `.item` in source order (QML evaluates grouped-property assignments in that order here).
- **`PopupWindow.grabFocus` is not compatible with a manual `visible` binding.** It forces `visible` to `false` itself on outside-click, which fights a plain `visible: entry !== null` binding and corrupts the popup (this broke the dock's context menu once already — see git-blame-equivalent context in the conversation, not tracked in this file). Use `Quickshell.Hyprland.HyprlandFocusGrab` instead: it only *detects* the outside click (`cleared()` signal) and leaves closing to your own code, so `visible` stays a normal binding. It also needs a short delay (~30ms) between the window becoming visible and setting `active: true` on the grab — activating in the same instant loses a race with the compositor mapping the surface and the grab silently fails.
- **Icon theme**: `Quickshell.iconPath()`/`IconImage` resolve through `QIcon::fromTheme()`, which is not guaranteed to pick up the desktop's configured GTK icon theme (e.g. Papirus-Dark) automatically under Quickshell's minimal Wayland QPA. Force it explicitly with `//@ pragma IconTheme Papirus-Dark` at the top of `shell.qml` rather than relying on ambient theme detection.
- **`FileView.loaded`'s change notification is `loadedOrAsyncChanged`, not `loadedChanged`** — QML's implicit `onLoadedChanged` handler will silently never fire. Use `Connections { function onLoadedOrAsyncChanged() { if (!view.loaded) return; ... } }` (see `DockPins.qml`).
- **`quickshell` processes reliably exit with a nonstandard code (observed as 144) when killed**, including by normal `pkill`/Ctrl-C during testing — this is quickshell's own crash handler re-raising a signal on termination, not a real crash. Don't treat a nonzero exit alone as evidence of a bug; check the actual log output.
