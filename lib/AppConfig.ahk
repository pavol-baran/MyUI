; ============================================================
;  AppConfig - thin INI wrapper with an in-memory cache.
;  Usage:  Cfg.Get("Section","Key","default")
;          Cfg.Set("Section","Key", value)
;          Cfg.GetInt("Section","Key", 0)
;
;  Named AppConfig rather than Config: "Config" collides with
;  an existing symbol in the VS Code definitions and makes the
;  language server reject the constructor call.
; ============================================================

class AppConfig {
    __New(path := "") {
        this.path  := path ? path : A_ScriptDir "\data\settings.ini"
        this.cache := Map()
        this.EnsureFile()
    }

    EnsureFile() {
        dir := RegExReplace(this.path, "\\[^\\]+$")
        if !DirExist(dir)
            DirCreate(dir)
        if !FileExist(this.path) {
            FileAppend("", this.path, "UTF-8")
            ; seed defaults
            this.Set("General", "ShowOverlayOnStart", "1")
            this.Set("Overlay", "X", "40")
            this.Set("Overlay", "Y", "40")
            this.Set("Overlay", "FontSize", "11")
            this.Set("Overlay", "FontColor", "FFFFFF")
        }
    }

    Get(section, key, default := "") {
        id := section "|" key
        if this.cache.Has(id)
            return this.cache[id]
        val := IniRead(this.path, section, key, default)
        this.cache[id] := val
        return val
    }

    ; Numeric read. INI values are always strings, so unary +
    ; is used to coerce - avoids Integer() which the language
    ; server flags as an unassigned variable.
    GetInt(section, key, default := 0) {
        val := this.Get(section, key, default)
        return IsNumber(val) ? val + 0 : default
    }

    Set(section, key, value) {
        this.cache[section "|" key] := value
        IniWrite(value, this.path, section, key)
    }

    Flush() {
        ; writes are immediate today; hook kept for future batching
    }
}
