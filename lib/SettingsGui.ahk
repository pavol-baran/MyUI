; ============================================================
;  SettingsGui
;  Single settings window. Tabs are the extension point:
;  each new feature area gets its own tab section below.
; ============================================================

class SettingsGui {
    static win := ""
    static ctl := Map()

    static Show() {
        if (SettingsGui.win) {
            SettingsGui.win.Show()
            return
        }
        SettingsGui.Build()
        SettingsGui.win.Show("w520 h500")
    }

    static Build() {
        global Cfg, Overlay, Modules, APP_NAME, APP_VERSION
        g := Gui(
            "+Resize -MaximizeBox",
            APP_NAME " v" APP_VERSION " - Settings"
        ) g.SetFont("s9", "Segoe UI")
        g.OnEvent("Close", (*) => g.Hide())
        g.OnEvent("Escape", (*) => g.Hide())

        tabs := g.AddTab3(
            "x10 y10 w500 h440",
            [
                "General",
                "Overlay",
                "Modules",
                "Buff Monitor",
                "Tempest Bell"
            ]
        )
        SettingsGui.ctl["tabs"] := tabs

        ; ---------------- General ----------------
        tabs.UseTab("General")
        cbStart := g.AddCheckbox("x28 y50 w340", "Show overlay on startup")
        cbStart.Value := (Cfg.Get("General", "ShowOverlayOnStart", "1") = "1")
        cbStart.OnEvent("Click", (c, *) =>
            Cfg.Set("General", "ShowOverlayOnStart", c.Value ? "1" : "0"))
        SettingsGui.ctl["cbStart"] := cbStart

        g.AddText("x28 y90 w340", "Hotkeys:")
        g.AddText("x28 y110 w340",
            "F1`tToggle overlay`nF2`tSettings`nCtrl+Alt+R`tReload`nCtrl+Alt+Q`tExit")

        ; ---------------- Overlay ----------------
        tabs.UseTab("Overlay")
        g.AddText("x28 y50 w60", "X")
        eX := g.AddEdit("x88 y46 w70 Number", Cfg.Get("Overlay", "X", "40"))
        g.AddText("x28 y82 w60", "Y")
        eY := g.AddEdit("x88 y78 w70 Number", Cfg.Get("Overlay", "Y", "40"))
        g.AddText("x28 y114 w60", "Font size")
        eS := g.AddEdit("x88 y110 w70 Number", Cfg.Get("Overlay", "FontSize", "11"))
        g.AddText("x28 y146 w60", "Colour")
        eC := g.AddEdit("x88 y142 w70", Cfg.Get("Overlay", "FontColor", "FFFFFF"))

        SettingsGui.ctl["eX"] := eX, SettingsGui.ctl["eY"] := eY
        SettingsGui.ctl["eS"] := eS, SettingsGui.ctl["eC"] := eC

        bApply := g.AddButton("x28 y182 w110 h26", "Apply position")
        bApply.OnEvent("Click", (*) => SettingsGui.ApplyPosition())

        bFont := g.AddButton("x148 y182 w130 h26", "Apply font (reload)")
        bFont.OnEvent("Click", (*) => SettingsGui.ApplyFont())

        g.AddText("x28 y220 w340 cGray",
            "Font changes rebuild the overlay, so the script reloads.")

        ; ---------------- Modules ----------------
        tabs.UseTab("Modules")
        names := Modules.Names()
        if (names.Length = 0) {
            g.AddText("x28 y50 w340 cGray",
                "No modules registered yet.`n`nAdd a file under \modules, then #Include"
                . " and register it`nin MyUI.ahk. It will appear here automatically.")
        } else {
            y := 50
            for _, name in names {
                cb := g.AddCheckbox("x28 y" y " w340", name)
                cb.Value := Modules.IsEnabled(name)
                cb.OnEvent("Click", SettingsGui.MakeToggle(name))
                y += 26

                if (name = "Buff Monitor") {
                    buffModule := Modules.Get("Buff Monitor")

                    cbDebug := g.AddCheckbox(
                        "x48 y" y " w320",
                        "Debug mode - show Python console"
                    )

                    cbDebug.Value := buffModule.debugMode

                    cbDebug.OnEvent(
                        "Click",
                        (c, *) => buffModule.SetDebugMode(c.Value)
                    )

                    SettingsGui.ctl["cbBuffDebug"] := cbDebug
                    y += 30
                }
            }
        }
        ; ---------------- Buff Monitor ----------------

        tabs.UseTab("Buff Monitor")

        buffModule := Modules.Get("Buff Monitor")

        g.AddText("x28 y50 w115", "Overlay X")
        eBuffX := g.AddEdit(
            "x150 y46 w90 Number",
            Cfg.Get("BuffMonitor", "OverlayX", "1650")
        )

        g.AddText("x270 y50 w90", "Overlay Y")
        eBuffY := g.AddEdit(
            "x360 y46 w90 Number",
            Cfg.Get("BuffMonitor", "OverlayY", "760")
        )

        g.AddText("x28 y84 w115", "Scale")
        eBuffScale := g.AddEdit(
            "x150 y80 w90",
            Cfg.Get("BuffMonitor", "Scale", "1.25")
        )

        g.AddText("x270 y84 w90", "Timer area")
        eBuffExtra := g.AddEdit(
            "x360 y80 w90 Number",
            Cfg.Get("BuffMonitor", "ExtraBelowIcon", "28")
        )

        g.AddText("x28 y118 w115", "Detection, ms")
        eBuffDetection := g.AddEdit(
            "x150 y114 w90 Number",
            Cfg.Get(
                "BuffMonitor",
                "DetectionIntervalMs",
                "200"
            )
        )

        g.AddText("x270 y118 w90", "Display, ms")
        eBuffDisplay := g.AddEdit(
            "x360 y114 w90 Number",
            Cfg.Get(
                "BuffMonitor",
                "DisplayIntervalMs",
                "50"
            )
        )

        g.AddText("x28 y152 w115", "Misses before gone")
        eBuffMisses := g.AddEdit(
            "x150 y148 w90 Number",
            Cfg.Get("BuffMonitor", "MissesBeforeGone", "2")
        )

        g.AddText("x28 y186 w115", "Rend threshold")
        eBuffRendThreshold := g.AddEdit(
            "x150 y182 w90",
            Cfg.Get("BuffMonitor", "RendThreshold", "0.72")
        )

        g.AddText("x270 y186 w90", "Charge threshold")
        eBuffChargeThreshold := g.AddEdit(
            "x360 y182 w90",
            Cfg.Get(
                "BuffMonitor",
                "PowerChargeThreshold",
                "0.72"
            )
        )

        cbBuffPlus := g.AddCheckbox(
            "x28 y224 w300",
            "Show green + when Power Charge is available"
        )

        cbBuffPlus.Value :=
            Cfg.Get(
                "BuffMonitor",
                "ShowPowerChargePlus",
                "1"
            ) = "1"

        cbBuffActiveOnly := g.AddCheckbox(
            "x28 y252 w300",
            "Show only while Path of Exile 2 is active"
        )

        cbBuffActiveOnly.Value :=
            Cfg.Get(
                "BuffMonitor",
                "ShowOnlyWhenPoeActive",
                "1"
            ) = "1"

        cbBuffDebugTab := g.AddCheckbox(
            "x28 y280 w300",
            "Debug mode: show Python console"
        )

        cbBuffDebugTab.Value := buffModule.debugMode

        SettingsGui.ctl["eBuffX"] := eBuffX
        SettingsGui.ctl["eBuffY"] := eBuffY
        SettingsGui.ctl["eBuffScale"] := eBuffScale
        SettingsGui.ctl["eBuffExtra"] := eBuffExtra
        SettingsGui.ctl["eBuffDetection"] := eBuffDetection
        SettingsGui.ctl["eBuffDisplay"] := eBuffDisplay
        SettingsGui.ctl["eBuffMisses"] := eBuffMisses

        SettingsGui.ctl[
            "eBuffRendThreshold"
            ] := eBuffRendThreshold

        SettingsGui.ctl[
            "eBuffChargeThreshold"
            ] := eBuffChargeThreshold

        SettingsGui.ctl["cbBuffPlus"] := cbBuffPlus
        SettingsGui.ctl[
            "cbBuffActiveOnly"
            ] := cbBuffActiveOnly

        SettingsGui.ctl[
            "cbBuffDebugTab"
            ] := cbBuffDebugTab

        bBuffApply := g.AddButton(
            "x28 y324 w150 h30 Default",
            "Apply and Restart"
        )

        bBuffApply.OnEvent(
            "Click",
            (*) => SettingsGui.ApplyBuffMonitor()
        )

        g.AddText(
            "x28 y368 w430 cGray",
            "Changes are saved to settings.ini and the Buff Monitor "
            . "sidecar is restarted."
        )

        ; ---------------- Tempest Bell ----------------

        tabs.UseTab("Tempest Bell")

        g.AddText("x28 y50 w100", "Source X")

        eBellSourceX := g.AddEdit(
            "x130 y46 w90 Number",
            Cfg.Get("TempestBell", "SourceX", "0")
        )

        g.AddText("x270 y50 w100", "Source Y")

        eBellSourceY := g.AddEdit(
            "x370 y46 w90 Number",
            Cfg.Get("TempestBell", "SourceY", "0")
        )

        g.AddText("x28 y84 w100", "Source width")

        eBellSourceW := g.AddEdit(
            "x130 y80 w90 Number",
            Cfg.Get("TempestBell", "SourceWidth", "64")
        )

        g.AddText("x270 y84 w100", "Source height")

        eBellSourceH := g.AddEdit(
            "x370 y80 w90 Number",
            Cfg.Get("TempestBell", "SourceHeight", "64")
        )

        g.AddText("x28 y118 w100", "Target X")

        eBellTargetX := g.AddEdit(
            "x130 y114 w90 Number",
            Cfg.Get("TempestBell", "TargetX", "1200")
        )

        g.AddText("x270 y118 w100", "Target Y")

        eBellTargetY := g.AddEdit(
            "x370 y114 w90 Number",
            Cfg.Get("TempestBell", "TargetY", "500")
        )

        g.AddText("x28 y152 w100", "Scale")

        eBellScale := g.AddEdit(
            "x130 y148 w90",
            Cfg.Get("TempestBell", "Scale", "1.0")
        )

        g.AddText("x270 y152 w100", "Opacity")

        eBellOpacity := g.AddEdit(
            "x370 y148 w90 Number",
            Cfg.Get("TempestBell", "Opacity", "255")
        )

        g.AddText("x28 y186 w100", "Refresh, ms")

        eBellRefresh := g.AddEdit(
            "x130 y182 w90 Number",
            Cfg.Get(
                "TempestBell",
                "RefreshIntervalMs",
                "33"
            )
        )

        cbBellActiveOnly := g.AddCheckbox(
            "x28 y224 w330",
            "Show only while Path of Exile 2 is active"
        )

        cbBellActiveOnly.Value := (
            Cfg.Get(
                "TempestBell",
                "ShowOnlyWhenPoeActive",
                "1"
            ) = "1"
        )

        SettingsGui.ctl["eBellSourceX"] := eBellSourceX
        SettingsGui.ctl["eBellSourceY"] := eBellSourceY
        SettingsGui.ctl["eBellSourceW"] := eBellSourceW
        SettingsGui.ctl["eBellSourceH"] := eBellSourceH
        SettingsGui.ctl["eBellTargetX"] := eBellTargetX
        SettingsGui.ctl["eBellTargetY"] := eBellTargetY
        SettingsGui.ctl["eBellScale"] := eBellScale
        SettingsGui.ctl["eBellOpacity"] := eBellOpacity
        SettingsGui.ctl["eBellRefresh"] := eBellRefresh
        SettingsGui.ctl["cbBellActiveOnly"] := cbBellActiveOnly

        bBellApply := g.AddButton(
            "x28 y270 w150 h30",
            "Apply Clone Settings"
        )

        bBellApply.OnEvent(
            "Click",
            (*) => SettingsGui.ApplyTempestBell()
        )

        g.AddText(
            "x28 y314 w430 cGray",
            "Coordinates are relative to the PoE2 client area.`n"
            . "Click Apply to update the clone."
        )

        tabs.UseTab()
        g.AddButton(
            "x400 y460 w100 h28",
            "Close"
        )

        SettingsGui.win := g
    }

    static ApplyPosition() {
        global Overlay
        x := SettingsGui.ctl["eX"].Value
        y := SettingsGui.ctl["eY"].Value
        ; Edit controls with the Number style still yield strings;
        ; unary + coerces without needing Integer()
        Overlay.Move(x + 0, y + 0)
    }

    static ApplyFont() {
        global Cfg
        Cfg.Set("Overlay", "FontSize", SettingsGui.ctl["eS"].Value)
        Cfg.Set("Overlay", "FontColor", SettingsGui.ctl["eC"].Value)
        Reload()
    }

    static ApplyBuffMonitor() {
        global Modules

        c := SettingsGui.ctl

        scale := Trim(c["eBuffScale"].Value)
        rendThreshold := Trim(
            c["eBuffRendThreshold"].Value
        )
        chargeThreshold := Trim(
            c["eBuffChargeThreshold"].Value
        )

        if !IsNumber(scale) || scale < 0.25 || scale > 5 {
            MsgBox(
                "Scale must be between 0.25 and 5.0.",
                "Buff Monitor",
                "Icon!"
            )
            return
        }

        if (
            !IsNumber(rendThreshold)
            || rendThreshold < 0
            || rendThreshold > 1
        ) {
            MsgBox(
                "Rend threshold must be between 0 and 1.",
                "Buff Monitor",
                "Icon!"
            )
            return
        }

        if (
            !IsNumber(chargeThreshold)
            || chargeThreshold < 0
            || chargeThreshold > 1
        ) {
            MsgBox(
                "Power Charge threshold must be between 0 and 1.",
                "Buff Monitor",
                "Icon!"
            )
            return
        }

        settings := Map(
            "OverlayX",
            c["eBuffX"].Value + 0,
            "OverlayY",
            c["eBuffY"].Value + 0,
            "Scale",
            scale,
            "DetectionIntervalMs",
            c["eBuffDetection"].Value + 0,
            "DisplayIntervalMs",
            c["eBuffDisplay"].Value + 0,
            "ExtraBelowIcon",
            c["eBuffExtra"].Value + 0,
            "MissesBeforeGone",
            c["eBuffMisses"].Value + 0,
            "RendThreshold",
            rendThreshold,
            "PowerChargeThreshold",
            chargeThreshold,
            "ShowPowerChargePlus",
            c["cbBuffPlus"].Value ? "1" : "0",
            "ShowOnlyWhenPoeActive",
            c["cbBuffActiveOnly"].Value ? "1" : "0"
        )

        buffModule := Modules.Get("Buff Monitor")

        buffModule.SetDebugMode(
            c["cbBuffDebugTab"].Value
        )

        buffModule.ApplySettings(settings)
    }

    static ApplyTempestBell() {
        global Modules

        c := SettingsGui.ctl

        sourceW := c["eBellSourceW"].Value + 0
        sourceH := c["eBellSourceH"].Value + 0
        scale := Trim(c["eBellScale"].Value)
        opacity := c["eBellOpacity"].Value + 0
        refreshMs := c["eBellRefresh"].Value + 0

        if (sourceW < 1 || sourceH < 1) {
            MsgBox(
                "Source width and height must be greater than zero.",
                "Tempest Bell",
                "Icon!"
            )
            return
        }

        if (
            !IsNumber(scale)
            || scale < 0.1
            || scale > 5
        ) {
            MsgBox(
                "Scale must be between 0.1 and 5.0.",
                "Tempest Bell",
                "Icon!"
            )
            return
        }

        if (
            opacity < 0
            || opacity > 255
        ) {
            MsgBox(
                "Opacity must be between 0 and 255.",
                "Tempest Bell",
                "Icon!"
            )
            return
        }

        if (
            refreshMs < 16
            || refreshMs > 1000
        ) {
            MsgBox(
                "Refresh interval must be between 16 and 1000 ms.",
                "Tempest Bell",
                "Icon!"
            )
            return
        }

        settings := Map(
            "SourceX",
            c["eBellSourceX"].Value + 0,
            "SourceY",
            c["eBellSourceY"].Value + 0,
            "SourceWidth",
            sourceW,
            "SourceHeight",
            sourceH,
            "TargetX",
            c["eBellTargetX"].Value + 0,
            "TargetY",
            c["eBellTargetY"].Value + 0,
            "Scale",
            scale,
            "Opacity",
            opacity,
            "RefreshIntervalMs",
            refreshMs,
            "ShowOnlyWhenPoeActive",
            c["cbBellActiveOnly"].Value ? "1" : "0"
        )

        bellModule := Modules.Get("Tempest Bell")

        if !bellModule {
            MsgBox(
                "The Tempest Bell module is not registered.",
                "Tempest Bell",
                "Icon!"
            )
            return
        }

        bellModule.ApplySettings(settings)
    }

    ; separate factory so each checkbox closes over its own name
    static MakeToggle(name) {
        return (c, *) => Modules.SetEnabled(name, c.Value)
    }
}