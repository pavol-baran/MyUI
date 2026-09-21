; ============================================================
;  Config - thin INI wrapper with an in-memory cache.
;  Usage:  Cfg.Get("Section","Key","default")
;          Cfg.Set("Section","Key", value)
; ============================================================

class Config {
    __New(path) {
        this.path  := path
        this.cache := Map()
        this.dirty := false
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
            this.Flush()
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

    Set(section, key, value) {
        this.cache[section "|" key] := value
        IniWrite(value, this.path, section, key)
        this.dirty := false   ; IniWrite is immediate; kept for future batching
    }

    Flush() {
        ; placeholder - writes are immediate today, batched later if needed
    }
}
