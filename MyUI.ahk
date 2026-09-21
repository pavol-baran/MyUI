#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, OutputDebug

; ============================================================
;  MyUI - entry point
;  Loads config, libs and modules, then idles.
;  Add new features as files in /modules, register them below.
; ============================================================

SetWorkingDir(A_ScriptDir)
Persistent()

#Include lib\AppConfig.ahk
#Include lib\Overlay.ahk
#Include lib\SettingsGui.ahk
#Include lib\ModuleManager.ahk
#Include modules\BuffMonitor.ahk

; --- global singletons -------------------------------------
global APP_NAME    := "MyUI"
global APP_VERSION := "0.1.0"

global Cfg     := AppConfig(A_ScriptDir "\data\settings.ini")
global Overlay := OverlayWindow()
global Modules := ModuleManager()

; --- module registration -----------------------------------
; When you add a module, #Include it and register it here.
; Nothing registered yet - that is intentional for step 1.
;
;   #Include modules\Buffs.ahk
;   Modules.Register(BuffsModule())

Modules.Register(BuffMonitorModule())
Modules.InitAll()

; --- tray --------------------------------------------------
BuildTray()

; --- hotkeys -----------------------------------------------
Hotkey("F1", (*) => Overlay.Toggle())
Hotkey("F2", (*) => SettingsGui.Show())
Hotkey("^!r", (*) => Reload())
Hotkey("^!q", (*) => ExitApp())

; --- startup -----------------------------------------------
if (Cfg.Get("General", "ShowOverlayOnStart", "1") = "1")
    Overlay.Show()

Overlay.SetLine("status", APP_NAME " v" APP_VERSION " - F1 overlay | F2 settings")

TrayTip(APP_NAME " running", "F1 = overlay  F2 = settings  Ctrl+Alt+Q = quit")

; ============================================================
BuildTray() {
    T := A_TrayMenu
    T.Delete()
    T.Add("Settings`tF2", (*) => SettingsGui.Show())
    T.Add("Toggle overlay`tF1", (*) => Overlay.Toggle())
    T.Add()
    T.Add("Reload`tCtrl+Alt+R", (*) => Reload())
    T.Add("Exit`tCtrl+Alt+Q", (*) => ExitApp())
    T.Default := "Settings`tF2"
    A_IconTip := APP_NAME " v" APP_VERSION
}

OnExit(SaveOnExit)

SaveOnExit(*) {
    global Cfg, Modules

    Modules.ShutdownAll()
    Cfg.Flush()
}
