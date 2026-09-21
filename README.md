# MyUI — step 1 skeleton

Bare AHK v2 app: starts, sits in tray, shows a transparent click-through
overlay, and has an empty-but-working settings window. No features yet.

## Requires
AutoHotkey **v2.0** (2.0.28 or newer). Run `MyUI.ahk`.

## Hotkeys
| Key | Action |
|---|---|
| `F1` | Toggle overlay |
| `F2` | Settings |
| `Ctrl+Alt+R` | Reload |
| `Ctrl+Alt+Q` | Exit |

## Layout
```
MyUI.ahk            entry point — include + register modules here
lib/
  Config.ahk        INI wrapper, cached
  Overlay.ahk       transparent click-through text overlay
  SettingsGui.ahk   tabbed settings window
  ModuleManager.ahk module lifecycle
modules/
  _Template.ahk     copy this to start a feature
data/
  settings.ini      auto-created on first run
img/                templates/assets later
```

## Adding a feature
1. Copy `modules/_Template.ahk`, rename the class and `Name`.
2. In `MyUI.ahk`: `#Include modules\Thing.ahk` then `Modules.Register(ThingModule())`
   — both above the `Modules.InitAll()` line.
3. It appears in **Settings → Modules** with an on/off toggle that persists.

## Overlay notes
- Click-through via `WS_EX_TRANSPARENT` (`+E0x20`) + layered (`+E0x80000`),
  background keyed out with `WinSetTransColor`.
- Uses a fixed pool of 12 text controls rather than rebuilding the GUI, so
  frequent updates stay cheap. Raise `MAX_LINES` if you need more.
- `-DPIScale` is set, so coordinates are literal pixels.
- Call `Overlay.SetLine("id", "text")` / `Overlay.ClearLine("id")`. Each caller
  owns its own id, so modules can't clobber each other.

## Next steps
- Attach overlay to a target window instead of screen coords.
- Drag-to-position mode (temporarily drop `+E0x20` while dragging).
- Python sidecar launch/teardown in `ModuleManager`.
