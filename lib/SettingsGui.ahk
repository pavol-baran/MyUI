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
        SettingsGui.win.Show("w420 h360")
    }

    static Build() {
        g := Gui("+Resize -MaximizeBox", APP_NAME " - Settings")
        g.SetFont("s9", "Segoe UI")
        g.OnEvent("Close", (*) => g.Hide())
        g.OnEvent("Escape", (*) => g.Hide())

        tabs := g.AddTab3("x10 y10 w400 h300", ["General", "Overlay", "Modules"])
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
        bApply.OnEvent("Click", (*) => Overlay.Move(Integer(eX.Value), Integer(eY.Value)))

        bFont := g.AddButton("x148 y182 w130 h26", "Apply font (reload)")
        bFont.OnEvent("Click", (*) => (
            Cfg.Set("Overlay", "FontSize", eS.Value),
            Cfg.Set("Overlay", "FontColor", eC.Value),
            Reload()
        ))

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
            }
        }

        tabs.UseTab()
        g.AddButton("x310 y320 w100 h28", "Close").OnEvent("Click", (*) => g.Hide())

        SettingsGui.win := g
    }

    ; separate factory so each checkbox closes over its own name
    static MakeToggle(name) {
        return (c, *) => Modules.SetEnabled(name, c.Value)
    }
}
