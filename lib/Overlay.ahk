; ============================================================
;  OverlayWindow
;  Transparent, always-on-top, click-through text overlay.
;
;  Uses a fixed pool of text controls so updates are cheap -
;  no GUI teardown/rebuild when content changes (important
;  once a detector starts pushing updates several times/sec).
;
;  API:
;    .Show() .Hide() .Toggle()
;    .SetLine(id, text)     create or update a labelled line
;    .ClearLine(id)         remove a line
;    .ClearAll()
;    .Move(x, y)
; ============================================================

class OverlayWindow {
    static MAX_LINES := 12
    static KEY_COLOR := "0F0F0E"   ; used as the transparent key

    __New() {
        this.visible := false
        this.order   := []          ; line ids, in display order
        this.lines   := Map()       ; id -> text string
        this.ctrls   := []          ; pooled text controls

        this.x     := Integer(Cfg.Get("Overlay", "X", "40"))
        this.y     := Integer(Cfg.Get("Overlay", "Y", "40"))
        this.size  := Integer(Cfg.Get("Overlay", "FontSize", "11"))
        this.color := Cfg.Get("Overlay", "FontColor", "FFFFFF")

        this.Build()
    }

    Build() {
        this.gui := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x20 +E0x80000 -DPIScale +Owner")
        this.gui.BackColor := OverlayWindow.KEY_COLOR
        this.gui.MarginX := 0
        this.gui.MarginY := 0
        this.gui.SetFont("s" this.size " Bold c" this.color, "Segoe UI")

        lineH := this.size * 2
        Loop OverlayWindow.MAX_LINES {
            c := this.gui.AddText(
                Format("x8 y{1} w520 h{2} BackgroundTrans", 6 + (A_Index - 1) * lineH, lineH),
                ""
            )
            c.Visible := false
            this.ctrls.Push(c)
        }

        ; show once off-screen so handles exist, then key out the background
        this.gui.Show("x-10000 y-10000 NoActivate AutoSize")
        WinSetTransColor(OverlayWindow.KEY_COLOR, this.gui)
        this.gui.Hide()
    }

    ; --- content --------------------------------------------
    SetLine(id, text) {
        if !this.lines.Has(id)
            this.order.Push(id)
        this.lines[id] := text
        this.Redraw()
    }

    ClearLine(id) {
        if !this.lines.Has(id)
            return
        this.lines.Delete(id)
        for i, v in this.order {
            if (v = id) {
                this.order.RemoveAt(i)
                break
            }
        }
        this.Redraw()
    }

    ClearAll() {
        this.lines := Map()
        this.order := []
        this.Redraw()
    }

    Redraw() {
        i := 0
        for _, id in this.order {
            if (++i > OverlayWindow.MAX_LINES)
                break
            c := this.ctrls[i]
            c.Text := this.lines[id]
            c.Visible := true
        }
        ; blank the unused remainder of the pool
        while (++i <= OverlayWindow.MAX_LINES) {
            c := this.ctrls[i]
            c.Text := ""
            c.Visible := false
        }
        if this.visible
            this.Reposition()
    }

    ; --- window ---------------------------------------------
    Reposition() {
        this.gui.Show(Format("x{1} y{2} NoActivate AutoSize", this.x, this.y))
    }

    Move(x, y) {
        this.x := x, this.y := y
        Cfg.Set("Overlay", "X", x)
        Cfg.Set("Overlay", "Y", y)
        if this.visible
            this.Reposition()
    }

    Show() {
        this.visible := true
        this.Reposition()
    }

    Hide() {
        this.visible := false
        this.gui.Hide()
    }

    Toggle() {
        this.visible ? this.Hide() : this.Show()
    }
}
