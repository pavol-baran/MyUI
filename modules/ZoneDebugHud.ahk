; ============================================================
; Zone Debug HUD v0.2
;
; Adds the current PoE2 area and tracking state to MyUI's
; existing text overlay.
;
; Observational only. Sends no keyboard or mouse input.
; ============================================================

class ZoneDebugHudModule {
    Name := "Zone Debug HUD"

    __New() {
        this.active := false
        this.timer := ""

        this.gameExe := "PathOfExileSteam.exe"
        this.gameWindow := "ahk_exe " this.gameExe

        this.lastArea := ""
        this.lastAllowed := ""
        this.linesVisible := false
    }

    Init() {
        this.timer := ObjBindMethod(this, "Tick")
    }

    Enable() {
        if this.active
            return

        this.active := true
        this.lastArea := ""
        this.lastAllowed := ""

        this.Tick()
        SetTimer(this.timer, 250)

        OutputDebug(
            "[MyUI] Zone Debug HUD enabled`n"
        )
    }

    Disable() {
        if !this.active
            return

        this.active := false

        if this.timer
            SetTimer(this.timer, 0)

        this.ClearLines()

        OutputDebug(
            "[MyUI] Zone Debug HUD disabled`n"
        )
    }

    Tick() {
        global Overlay, ZoneContext

        if !this.active
            return

        ; Do not show zone information outside PoE2.
        if !ProcessExist(this.gameExe) {
            this.ClearLines()
            return
        }

        ; Hide the zone information while another application is active.
        if !WinActive(this.gameWindow) {
            this.ClearLines()
            return
        }

        area := ZoneContext.currentArea
        allowed := ZoneContext.isTrackingAllowed

        if (
            area = this.lastArea
            && allowed = this.lastAllowed
            && this.linesVisible
        ) {
            return
        }

        this.lastArea := area
        this.lastAllowed := allowed
        this.linesVisible := true

        if allowed
            status := "TRACKING ENABLED"
        else
            status := "TRACKING BLOCKED"

        Overlay.SetLine(
            "zone-context-status",
            status
        )

        Overlay.SetLine(
            "zone-context-area",
            "Area: " area
        )
    }

    ClearLines() {
        global Overlay

        if !this.linesVisible
            return

        Overlay.ClearLine(
            "zone-context-status"
        )

        Overlay.ClearLine(
            "zone-context-area"
        )

        this.linesVisible := false
        this.lastArea := ""
        this.lastAllowed := ""
    }
}