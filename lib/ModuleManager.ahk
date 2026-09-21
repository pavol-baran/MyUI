; ============================================================
;  ModuleManager
;  Holds registered feature modules and drives their lifecycle.
;
;  A module is any object exposing:
;     Name      (string property)
;     Init()    called once at startup
;     Enable()  called when switched on
;     Disable() called when switched off
;
;  See modules\_Template.ahk for a copy-paste starting point.
; ============================================================

class ModuleManager {
    __New() {
        this.items := Map()      ; name -> module object
    }

    Register(mod) {
        this.items[mod.Name] := mod
        return mod
    }

    InitAll() {
        global Cfg
        for name, mod in this.items {
            try {
                mod.Init()
                if (Cfg.Get("Modules", name, "1") = "1")
                    mod.Enable()
            } catch as e {
                OutputDebug("[MyUI] module '" name "' failed to init: " e.Message)
            }
        }
    }

    SetEnabled(name, on) {
        global Cfg
        if !this.items.Has(name)
            return
        mod := this.items[name]
        if on
            mod.Enable()
        else
            mod.Disable()
        Cfg.Set("Modules", name, on ? "1" : "0")
    }

    IsEnabled(name) {
        global Cfg
        return Cfg.Get("Modules", name, "1") = "1"
    }

    Names() {
        out := []
        for name, _ in this.items
            out.Push(name)
        return out
    }
}
