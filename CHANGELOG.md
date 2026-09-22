# Changelog

## 0.2.0-beta.1

First beta build.

### Added

- Modular AutoHotkey v2 application structure
- Persistent INI configuration
- Buff Monitor Python sidecar lifecycle
- Rend and Power Charge template detection
- Transparent, click-through Rend overlay
- Configurable position, scale, thresholds, and refresh timing
- Silent and debug Python modes
- Tempest Bell fixed-region Clone Frame
- GDI+ layered-window rendering
- Client.txt zone-context detection
- Automatic pause in hideouts and hub areas
- Optional zone-context information in the main overlay
- Clean module and sidecar shutdown
- Project-local Python virtual environment support

### Performance

Measured Buff Monitor v1.6.2:

- Approximately 0.55% average CPU while active
- Approximately 0.01% average CPU while paused
- Approximately 60 MB resident memory

### Known limitations

- Rend destination position is fixed rather than attached to the animated HUD.
- Tempest Bell source coordinates require manual configuration.
- The settings interface is functional but still under active development.