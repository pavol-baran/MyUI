; ============================================================
; CloneFrame v0.1
;
; Reusable fixed-region screen clone for MyUI.
;
; Rendering approach adapted from Exile-UI Clone Frames.
; Copyright (c) 2022 Lailloken
; Licensed under the MIT License.
; See LICENSES\Exile-UI-MIT.txt.
; ============================================================

class CloneFrame {
    static gdipToken := 0
    static instanceCount := 0

    __New(options) {
        this.sourceX := options.Get("SourceX", 0)
        this.sourceY := options.Get("SourceY", 0)
        this.sourceW := options.Get("SourceW", 64)
        this.sourceH := options.Get("SourceH", 64)

        this.targetX := options.Get("TargetX", 0)
        this.targetY := options.Get("TargetY", 0)

        this.scale := options.Get("Scale", 1.0)
        this.opacity := options.Get("Opacity", 255)
        this.refreshMs := options.Get("RefreshMs", 33)

        this.visible := false
        this.running := false
        this.timer := ObjBindMethod(this, "Refresh")

        this.ValidateSettings()
        this.EnsureGdip()
        this.BuildWindow()

        CloneFrame.instanceCount += 1
    }

    EnsureGdip() {
        if CloneFrame.gdipToken
            return

        CloneFrame.gdipToken := Gdip_Startup()

        if !CloneFrame.gdipToken
            throw Error("GDI+ failed to start.")
    }

    ValidateSettings() {
        if (this.sourceW < 1 || this.sourceH < 1)
            throw Error(
                "CloneFrame source width and height must be positive."
            )

        if (this.scale <= 0)
            throw Error("CloneFrame scale must be greater than zero.")

        this.opacity := Max(0, Min(255, this.opacity))
        this.refreshMs := Max(16, this.refreshMs)
    }

    BuildWindow() {
        this.gui := Gui(
            "-Caption"
            . " +AlwaysOnTop"
            . " +ToolWindow"
            . " +E0x20"
            . " +E0x80000"
            . " -DPIScale"
        )

        this.gui.Show(
            "x-10000 y-10000"
            . " w1 h1"
            . " NoActivate"
        )

        this.hwnd := this.gui.Hwnd
        this.gui.Hide()
    }

    Start() {
        if this.running
            return

        this.running := true

        ; A layered window must be shown before its bitmap becomes visible.
        this.gui.Show("NA")

        this.Refresh()
        SetTimer(this.timer, this.refreshMs)
    }

    Stop() {
        if !this.running
            return

        this.running := false
        SetTimer(this.timer, 0)
        this.Hide()
    }

    Show() {
        this.visible := true
    }

    Hide() {
        this.visible := false

        if this.hwnd && WinExist("ahk_id " this.hwnd)
            this.gui.Hide()
    }

    Refresh() {
        if !this.running
            return

        targetW := Max(
            1,
            Round(this.sourceW * this.scale)
        )

        targetH := Max(
            1,
            Round(this.sourceH * this.scale)
        )

        pBitmap := 0
        hbm := 0
        hdc := 0
        oldBitmap := 0
        graphics := 0

        try {
            sourceArea := (
                this.sourceX
                . "|"
                . this.sourceY
                . "|"
                . this.sourceW
                . "|"
                . this.sourceH
            )

            pBitmap := Gdip_BitmapFromScreen(sourceArea)

            if !pBitmap
                return

            hbm := CreateDIBSection(
                targetW,
                targetH
            )

            hdc := CreateCompatibleDC()
            oldBitmap := SelectObject(hdc, hbm)

            graphics := Gdip_GraphicsFromHDC(hdc)

            ; Nearest-neighbour scaling keeps HUD text and counters crisp.
            Gdip_SetInterpolationMode(graphics, 5)

            Gdip_DrawImage(
                graphics,
                pBitmap,
                0,
                0,
                targetW,
                targetH,
                0,
                0,
                this.sourceW,
                this.sourceH
            )

            UpdateLayeredWindow(
                this.hwnd,
                hdc,
                this.targetX,
                this.targetY,
                targetW,
                targetH,
                this.opacity
            )

            this.visible := true
        } catch as e {
            OutputDebug(
                "[MyUI] CloneFrame refresh failed: "
                e.Message
                "`n"
            )
        } finally {
            if graphics
                Gdip_DeleteGraphics(graphics)

            if oldBitmap && hdc
                SelectObject(hdc, oldBitmap)

            if hbm
                DeleteObject(hbm)

            if hdc
                DeleteDC(hdc)

            if pBitmap
                Gdip_DisposeImage(pBitmap)
        }
    }

    UpdateSettings(options) {
        wasRunning := this.running

        if wasRunning
            this.Stop()

        this.sourceX := options.Get(
            "SourceX",
            this.sourceX
        )

        this.sourceY := options.Get(
            "SourceY",
            this.sourceY
        )

        this.sourceW := options.Get(
            "SourceW",
            this.sourceW
        )

        this.sourceH := options.Get(
            "SourceH",
            this.sourceH
        )

        this.targetX := options.Get(
            "TargetX",
            this.targetX
        )

        this.targetY := options.Get(
            "TargetY",
            this.targetY
        )

        this.scale := options.Get(
            "Scale",
            this.scale
        )

        this.opacity := options.Get(
            "Opacity",
            this.opacity
        )

        this.refreshMs := options.Get(
            "RefreshMs",
            this.refreshMs
        )

        this.ValidateSettings()

        if wasRunning
            this.Start()
    }

    Destroy() {
        this.Stop()

        if this.gui {
            this.gui.Destroy()
            this.gui := ""
        }

        this.hwnd := 0

        CloneFrame.instanceCount := Max(
            0,
            CloneFrame.instanceCount - 1
        )

        if (
            CloneFrame.instanceCount = 0
            && CloneFrame.gdipToken
        ) {
            Gdip_Shutdown(CloneFrame.gdipToken)
            CloneFrame.gdipToken := 0
        }
    }
}