; ============================================================
;  Module template - copy this file, rename the class, then in
;  MyUI.ahk add:
;
;      #Include modules\MyThing.ahk
;      Modules.Register(MyThingModule())
;
;  It then shows up automatically in Settings > Modules.
; ============================================================

class TemplateModule {
    Name := "Template"

    __New() {
        this.active := false
        this.timer  := ""
    }

    ; runs once at startup - set up state, load assets
    Init() {
    }

    ; runs when the module is switched on
    Enable() {
        if this.active
            return
        this.active := true
        this.timer := ObjBindMethod(this, "Tick")
        SetTimer(this.timer, 250)
    }

    ; runs when switched off - undo everything Enable did
    Disable() {
        if !this.active
            return
        this.active := false
        if this.timer
            SetTimer(this.timer, 0)
        Overlay.ClearLine(this.Name)
    }

    Tick() {
        ; example: write one line to the overlay
        ; Overlay.SetLine(this.Name, "hello " A_TickCount)
    }
}
