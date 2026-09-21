; ============================================================
; Buff Monitor module v0.2
; Starts the Python sidecar while Path of Exile is running.
; Captures Python errors and prevents restart loops.
; ============================================================

class BuffMonitorModule {
    Name := "Buff Monitor"

    __New() {
        this.active := false
        this.pythonPid := 0
        this.timer := ""

        this.sidecarDir := A_ScriptDir "\sidecars\BuffMonitor"
        this.scriptPath := this.sidecarDir "\poe_buff_overlay_v1.4.py"
        this.logPath := this.sidecarDir "\buff_monitor.log"

        global Cfg

        this.pythonDir := "C:\Users\pavol\AppData\Local\Programs\Python\Python312"
        this.debugMode := Cfg.Get("BuffMonitor", "DebugMode", "0") = "1"
        this.UpdatePythonExe()

        this.gameExe := "PathOfExileSteam.exe"

        this.lastStartTick := 0
        this.restartDelayMs := 5000
        this.failedStarts := 0
        this.maxFailedStarts := 3
    }

    Init() {
        if !DirExist(this.sidecarDir) {
            throw Error(
                "Buff Monitor folder not found:`n" this.sidecarDir
            )
        }

        if !FileExist(this.scriptPath) {
            throw Error(
                "Buff Monitor Python file not found:`n" this.scriptPath
            )
        }
    }

    Enable() {
        if this.active
            return

        this.active := true
        this.failedStarts := 0
        this.lastStartTick := 0

        this.timer := ObjBindMethod(this, "Tick")

        this.Tick()
        SetTimer(this.timer, 1000)

        OutputDebug("[MyUI] Buff Monitor enabled`n")
    }

    Disable() {
        if !this.active
            return

        this.active := false

        if this.timer
            SetTimer(this.timer, 0)

        this.StopPython()

        OutputDebug("[MyUI] Buff Monitor disabled`n")
    }

    Tick() {
        if !this.active
            return

        poeRunning := ProcessExist(this.gameExe) != 0
        pythonRunning := this.IsPythonRunning()

        if !poeRunning {
            if pythonRunning
                this.StopPython()

            return
        }

        if pythonRunning
            return

        ; Avoid launching repeatedly every second.
        if (A_TickCount - this.lastStartTick < this.restartDelayMs)
            return

        ; Stop retrying after repeated immediate failures.
        if (this.failedStarts >= this.maxFailedStarts) {
            OutputDebug(
                "[MyUI] Buff Monitor stopped retrying after "
                this.failedStarts
                " failures. Check buff_monitor.log.`n"
            )

            return
        }

        this.StartPython()
    }

    UpdatePythonExe() {
        this.pythonExe := this.pythonDir
            . (this.debugMode ? "\python.exe" : "\pythonw.exe")
    }

    SetDebugMode(enabled) {
        global Cfg

        enabled := enabled ? true : false

        if (this.debugMode = enabled)
            return

        this.debugMode := enabled
        this.UpdatePythonExe()

        Cfg.Set(
            "BuffMonitor",
            "DebugMode",
            enabled ? "1" : "0"
        )

        OutputDebug(
            "[MyUI] Buff Monitor debug mode: "
            (enabled ? "ON" : "OFF")
            "`n"
        )

        ; Restart the sidecar with the correct Python executable.
        if this.active {
            this.StopPython()

            this.failedStarts := 0
            this.lastStartTick := 0

            this.Tick()
        }
    }

    StartPython() {
        if this.IsPythonRunning()
            return

        this.lastStartTick := A_TickCount

        if !FileExist(this.pythonExe) {
            this.failedStarts := this.maxFailedStarts

            OutputDebug(
                "[MyUI] Python executable not found: "
                this.pythonExe
                "`n"
            )
            return
        }

        try {
            command := Format(
                '"{1}" "{2}"',
                this.pythonExe,
                this.scriptPath
            )

            Run(
                command,
                this.sidecarDir,
                "",
                &pid
            )

            this.pythonPid := pid

            OutputDebug(
                "[MyUI] Buff Monitor Python started. PID: "
                pid
                "`n"
            )

            SetTimer(
                ObjBindMethod(this, "CheckStartup", pid),
                -1500
            )
        } catch as e {
            this.pythonPid := 0
            this.failedStarts += 1

            OutputDebug(
                "[MyUI] Buff Monitor launch failed: "
                e.Message
                "`n"
            )
        }
    }


    CheckStartup(expectedPid) {
        if !this.active
            return

        if (this.pythonPid != expectedPid)
            return

        if ProcessExist(expectedPid) {
            this.failedStarts := 0

            OutputDebug(
                "[MyUI] Buff Monitor startup confirmed. PID: "
                expectedPid
                "`n"
            )

            return
        }

        this.pythonPid := 0
        this.failedStarts += 1

        OutputDebug(
            "[MyUI] Buff Monitor exited during startup. Failure "
            this.failedStarts
            " of "
            this.maxFailedStarts
            ". Check buff_monitor.log.`n"
        )
    }

    StopPython() {
        if !this.pythonPid
            return

        pid := this.pythonPid
        this.pythonPid := 0

        try {
            if ProcessExist(pid)
                ProcessClose(pid)
        } catch as e {
            OutputDebug(
                "[MyUI] Failed to stop Buff Monitor: "
                e.Message
                "`n"
            )
        }

        OutputDebug(
            "[MyUI] Buff Monitor Python stopped. PID: "
            pid
            "`n"
        )
    }

    IsPythonRunning() {
        if !this.pythonPid
            return false

        if ProcessExist(this.pythonPid)
            return true

        this.pythonPid := 0
        return false
    }

    WriteModuleError(message) {
        try {
            FileAppend(
                FormatTime(, "yyyy-MM-dd HH:mm:ss")
                " "
                message
                "`n",
                this.logPath,
                "UTF-8"
            )
        }
    }
}