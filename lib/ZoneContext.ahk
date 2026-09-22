; ============================================================
; ZoneContextService v0.1
;
; Observational Client.txt reader for MyUI.
;
; Reads the current PoE2 area ID and determines whether visual
; tracking features should run in that area.
;
; This service does not send any keyboard or mouse input.
; ============================================================

class ZoneContextService {
    __New() {
        global Cfg

        this.currentArea := "Unknown"
        this.isTrackingAllowed := false
        this.logPosition := 0
        this.busy := false
        this.running := false

        this.pollIntervalMs := Cfg.GetInt(
            "ZoneContext",
            "PollIntervalMs",
            500
        )

        this.initialReadBytes := Cfg.GetInt(
            "ZoneContext",
            "InitialReadBytes",
            262144
        )

        this.blockedZones := Cfg.Get(
            "ZoneContext",
            "BlockedZones",
            "Hideout,Hub"
        )

        this.logFile := Cfg.Get(
            "ZoneContext",
            "LogFile",
            "C:\Program Files (x86)\Steam\steamapps\common"
            . "\Path of Exile 2\logs\Client.txt"
        )

        this.timer := ObjBindMethod(this, "Poll")
    }

    Start() {
        if this.running
            return

        this.running := true

        this.InitializeFromLog()

        SetTimer(
            this.timer,
            this.pollIntervalMs
        )

        OutputDebug(
            "[MyUI] Zone Context started`n"
        )
    }

    Stop() {
        if !this.running
            return

        this.running := false
        SetTimer(this.timer, 0)

        OutputDebug(
            "[MyUI] Zone Context stopped`n"
        )
    }

    InitializeFromLog() {
        if !FileExist(this.logFile) {
            this.currentArea := "Client.txt not found"
            this.isTrackingAllowed := false

            OutputDebug(
                "[MyUI] Zone Context log not found: "
                this.logFile
                "`n"
            )
            return
        }

        try {
            logSize := FileGetSize(this.logFile)
            startPosition := Max(
                0,
                logSize - this.initialReadBytes
            )

            file := FileOpen(
                this.logFile,
                "r",
                "UTF-8"
            )

            if !file {
                this.currentArea := "Cannot open Client.txt"
                this.isTrackingAllowed := false
                return
            }

            file.Pos := startPosition
            text := file.Read()
            file.Close()

            lastArea := this.FindLastArea(text)

            if lastArea
                this.UpdateArea(lastArea)
            else {
                this.currentArea := "Area not found"
                this.isTrackingAllowed := false
            }

            ; Future polling reads only newly appended content.
            this.logPosition := logSize
        } catch as e {
            this.currentArea := "Log initialization failed"
            this.isTrackingAllowed := false

            OutputDebug(
                "[MyUI] Zone Context initialization failed: "
                e.Message
                "`n"
            )
        }
    }

    Poll() {
        if !this.running || this.busy
            return

        this.busy := true

        try {
            if !FileExist(this.logFile) {
                this.SetUnavailable(
                    "Client.txt not found"
                )
                return
            }

            logSize := FileGetSize(this.logFile)

            ; The log was cleared, replaced, or rotated.
            if (logSize < this.logPosition)
                this.logPosition := 0

            if (logSize = this.logPosition)
                return

            file := FileOpen(
                this.logFile,
                "r",
                "UTF-8"
            )

            if !file {
                this.SetUnavailable(
                    "Cannot open Client.txt"
                )
                return
            }

            file.Pos := this.logPosition
            newText := file.Read(
                logSize - this.logPosition
            )

            this.logPosition := file.Pos
            file.Close()

            lastArea := this.FindLastArea(newText)

            if lastArea
                this.UpdateArea(lastArea)
        } catch as e {
            OutputDebug(
                "[MyUI] Zone Context polling failed: "
                e.Message
                "`n"
            )
        } finally {
            this.busy := false
        }
    }

    FindLastArea(text) {
        lastArea := ""
        position := 1

        pattern := "i)Generating level\s+\d+\s+area\s+\x22([^\x22]+)\x22"

        while RegExMatch(
            text,
            pattern,
            &match,
            position
        ) {
            lastArea := match[1]
            position := match.Pos + match.Len
        }

        return lastArea
    }

    UpdateArea(areaId) {
        if !areaId
            return

        oldArea := this.currentArea
        oldAllowed := this.isTrackingAllowed

        this.currentArea := areaId
        this.isTrackingAllowed := !this.IsBlocked(areaId)

        if (
            oldArea != this.currentArea
            || oldAllowed != this.isTrackingAllowed
        ) {
            if this.isTrackingAllowed
                status := "ENABLED"
            else
                status := "BLOCKED"

            message := (
                "[MyUI] Zone Context: "
                . this.currentArea
                . " | tracking "
                . status
                . "`n"
            )

            OutputDebug(message)
        }
    }

    IsBlocked(areaId) {
        for _, blockedText in StrSplit(
            this.blockedZones,
            ","
        ) {
            fragment := Trim(blockedText)

            if !fragment
                continue

            if InStr(areaId, fragment, false)
                return true
        }

        return false
    }

    SetUnavailable(reason) {
        if (
            this.currentArea = reason
            && !this.isTrackingAllowed
        ) {
            return
        }

        this.currentArea := reason
        this.isTrackingAllowed := false

        OutputDebug(
            "[MyUI] Zone Context unavailable: "
            reason
            "`n"
        )
    }

    ReloadSettings() {
        global Cfg

        this.blockedZones := Cfg.Get(
            "ZoneContext",
            "BlockedZones",
            "Hideout,Hub"
        )

        this.pollIntervalMs := Cfg.GetInt(
            "ZoneContext",
            "PollIntervalMs",
            500
        )

        SetTimer(this.timer, 0)

        if this.running {
            SetTimer(
                this.timer,
                this.pollIntervalMs
            )
        }

        areaKnown := this.currentArea != "Unknown"
        logAvailable := !InStr(
            this.currentArea,
            "Client.txt"
        )

        if (areaKnown && logAvailable) {
            this.isTrackingAllowed := !this.IsBlocked(
                this.currentArea
            )
        }
    }
}