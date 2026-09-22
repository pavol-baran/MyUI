; ============================================================
; Tempest Bell Clone v0.1
;
; Copies the fixed Tempest Bell skill slot from the PoE2 client
; and displays it elsewhere as a click-through clone frame.
; ============================================================

class TempestBellModule {
    Name := "Tempest Bell"

    __New() {
        this.active := false
        this.frame := ""
        this.timer := ""

        this.gameExe := "PathOfExileSteam.exe"
        this.gameWindow := "ahk_exe " this.gameExe
    }

    Init() {
        this.timer := ObjBindMethod(this, "Tick")
    }

    Enable() {
        if this.active
            return

        this.active := true

        this.CreateClone()
        this.Tick()

        ; Lifecycle and game-focus check.
        SetTimer(this.timer, 200)

        OutputDebug(
            "[MyUI] Tempest Bell enabled`n"
        )
    }

    Disable() {
        if !this.active
            return

        this.active := false

        if this.timer
            SetTimer(this.timer, 0)

        this.DestroyClone()

        OutputDebug(
            "[MyUI] Tempest Bell disabled`n"
        )
    }

    CreateClone() {
        global Cfg, CloneFrame

        if this.frame
            return

        this.frame := CloneFrame(
            Map(
                "SourceX",
                0,
                "SourceY",
                0,
                "SourceW",
                Cfg.GetInt(
                    "TempestBell",
                    "SourceWidth",
                    64
                ),
                "SourceH",
                Cfg.GetInt(
                    "TempestBell",
                    "SourceHeight",
                    64
                ),
                "TargetX",
                0,
                "TargetY",
                0,
                "Scale",
                Cfg.Get(
                    "TempestBell",
                    "Scale",
                    "1.0"
                ) + 0,
                "Opacity",
                Cfg.GetInt(
                    "TempestBell",
                    "Opacity",
                    255
                ),
                "RefreshMs",
                Cfg.GetInt(
                    "TempestBell",
                    "RefreshIntervalMs",
                    33
                )
            )
        )
    }

    DestroyClone() {
        if !this.frame
            return

        this.frame.Destroy()
        this.frame := ""
    }

    Tick() {
        global ZoneContext

        if !this.active
            return

        if !ZoneContext.isTrackingAllowed {
            if this.frame
                this.frame.Stop()

            return
        }

        if !ProcessExist(this.gameExe) {
            if this.frame
                this.frame.Stop()

            return
        }

        if !WinExist(this.gameWindow) {
            if this.frame
                this.frame.Stop()

            return
        }

        showOnlyActive := this.GetBoolSetting(
            "ShowOnlyWhenPoeActive",
            true
        )

        if (
            showOnlyActive
            && !WinActive(this.gameWindow)
        ) {
            if this.frame
                this.frame.Stop()

            return
        }

        if WinGetMinMax(this.gameWindow) = -1 {
            if this.frame
                this.frame.Stop()

            return
        }

        if !this.frame
            this.CreateClone()

        this.UpdateCoordinates()

        if !this.frame.running
            this.frame.Start()
    }

    UpdateCoordinates() {
        global Cfg

        WinGetClientPos(
            &clientX,
            &clientY,
            &clientW,
            &clientH,
            this.gameWindow
        )

        sourceX := Cfg.GetInt(
            "TempestBell",
            "SourceX",
            0
        )

        sourceY := Cfg.GetInt(
            "TempestBell",
            "SourceY",
            0
        )

        targetX := Cfg.GetInt(
            "TempestBell",
            "TargetX",
            0
        )

        targetY := Cfg.GetInt(
            "TempestBell",
            "TargetY",
            0
        )

        ; INI coordinates are relative to the PoE client.
        this.frame.sourceX := clientX + sourceX
        this.frame.sourceY := clientY + sourceY

        this.frame.targetX := clientX + targetX
        this.frame.targetY := clientY + targetY
    }

    ApplySettings(settings) {
        global Cfg

        for key, value in settings
            Cfg.Set("TempestBell", key, value)

        this.Restart()
    }

    Restart() {
        if !this.active
            return

        this.DestroyClone()
        this.CreateClone()
        this.Tick()

        OutputDebug(
            "[MyUI] Tempest Bell restarted with new settings`n"
        )
    }

    GetBoolSetting(key, defaultValue) {
        global Cfg

        defaultText := defaultValue ? "1" : "0"

        return (
            Cfg.Get(
                "TempestBell",
                key,
                defaultText
            ) = "1"
        )
    }
}