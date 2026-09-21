"""
Standalone PoE2 Rend overlay prototype v1.7 experimental

Uses files created by poe_manual_detector.py:
  detector_config.json
  template_rend.png
  template_power_charge.png

Run:
  python.exe poe_buff_overlay_v1.7-experimental.py

Controls:
  F8     Toggle overlay visibility (overlay remains click-through)
  F9     Toggle experimental HUD anchoring
  Esc    Exit

Observational only. This script captures screen pixels and never sends game input.
"""

import configparser
import json
import time
from pathlib import Path

import cv2
import mss
import numpy as np
import tkinter as tk
from PIL import Image, ImageTk
import win32api
import win32con
import win32gui

BASE = Path(__file__).resolve().parent
VERSION = "1.7-experimental"

CONFIG_FILE = BASE / "detector_config.json"
SETTINGS_FILE = BASE.parent.parent / "data" / "settings.ini"

WINDOW_TITLE = "Path of Exile 2"


# ------------------------ VISUAL CONSTANTS ------------------------

PADDING = 0

WINDOW_CHECK_INTERVAL_MS = 200

# Experimental HUD anchoring. The tracker captures a small strip immediately
# left of the configured overlay position and follows that strip locally.
HUD_TRACKING_ENABLED = True
HUD_TRACKING_INTERVAL_MS = 16
HUD_ANCHOR_WIDTH = 112
HUD_ANCHOR_HEIGHT = 24
HUD_ANCHOR_GAP = 6
HUD_ANCHOR_Y_OFFSET = 0
HUD_SEARCH_MARGIN = 32
HUD_MATCH_THRESHOLD = 0.42
HUD_POSITION_DEAD_ZONE = 1
HUD_STATS_INTERVAL_SECONDS = 5.0

# Exact transparency-key colour used by the Windows overlay.
TRANSPARENT_COLOUR = "#ff00ff"

SHOW_BORDER = False
BORDER_WIDTH = 1
BORDER_COLOUR = "#666666"

# ----------------------------------------------------------------


def load_app_settings():
    config = configparser.ConfigParser()
    config.read(SETTINGS_FILE, encoding="utf-8-sig")

    section = "BuffMonitor"

    def get_int(key, default, minimum=None, maximum=None):
        try:
            value = config.getint(section, key, fallback=default)
        except (ValueError, configparser.Error):
            value = default

        if minimum is not None:
            value = max(minimum, value)

        if maximum is not None:
            value = min(maximum, value)

        return value

    def get_float(key, default, minimum=None, maximum=None):
        try:
            value = config.getfloat(section, key, fallback=default)
        except (ValueError, configparser.Error):
            value = default

        if minimum is not None:
            value = max(minimum, value)

        if maximum is not None:
            value = min(maximum, value)

        return value

    def get_bool(key, default):
        try:
            return config.getboolean(
                section,
                key,
                fallback=default,
            )
        except (ValueError, configparser.Error):
            return default

    return {
        "overlay_x": get_int("OverlayX", 1650),
        "overlay_y": get_int("OverlayY", 760),
        "scale": get_float("Scale", 1.25, 0.25, 5.0),
        "detection_interval_ms": get_int(
            "DetectionIntervalMs",
            200,
            50,
            5000,
        ),
        "display_interval_ms": get_int(
            "DisplayIntervalMs",
            50,
            16,
            5000,
        ),
        "extra_below_icon": get_int(
            "ExtraBelowIcon",
            28,
            0,
            200,
        ),
        "misses_before_gone": get_int(
            "MissesBeforeGone",
            2,
            1,
            20,
        ),
        "rend_threshold": get_float(
            "RendThreshold",
            0.72,
            0.0,
            1.0,
        ),
        "power_charge_threshold": get_float(
            "PowerChargeThreshold",
            0.72,
            0.0,
            1.0,
        ),
        "show_power_charge_plus": get_bool(
            "ShowPowerChargePlus",
            True,
        ),
        "show_only_when_poe_active": get_bool(
            "ShowOnlyWhenPoeActive",
            True,
        ),
    }


def fail(message):
    print(f"\nERROR: {message}")
    input("Press Enter to close...")
    raise SystemExit(1)


def find_game_window():
    hwnd = win32gui.FindWindow(None, WINDOW_TITLE)
    if not hwnd:
        return None
    return hwnd


def client_origin(hwnd):
    return win32gui.ClientToScreen(hwnd, (0, 0))


def client_size(hwnd):
    left, top, right, bottom = win32gui.GetClientRect(hwnd)
    return right - left, bottom - top


def load_configuration():
    if not CONFIG_FILE.exists():
        fail(
            "detector_config.json is missing. Put this script in the same folder as your calibrated detector files."
        )
    try:
        cfg = json.loads(CONFIG_FILE.read_text(encoding="utf-8"))
    except Exception as exc:
        fail(f"Cannot read detector_config.json: {exc}")

    templates = {}
    for name in ("rend", "power_charge"):
        try:
            filename = cfg["templates"][name]["file"]
        except KeyError:
            fail(f"Configuration has no template entry for {name}.")
        image = cv2.imread(str(BASE / filename), cv2.IMREAD_COLOR)
        if image is None:
            fail(f"Cannot load {filename}.")
        templates[name] = image
    return cfg, templates


def match_template(search, template):
    if search.shape[0] < template.shape[0] or search.shape[1] < template.shape[1]:
        return 0.0, (0, 0)
    result = cv2.matchTemplate(search, template, cv2.TM_CCOEFF_NORMED)
    _, score, _, location = cv2.minMaxLoc(result)
    return float(score), location


def bgr_to_photo(image_bgr, scale):
    rgb = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
    image = Image.fromarray(rgb)
    if scale != 1.0:
        size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
        image = image.resize(size, Image.Resampling.NEAREST)
    return ImageTk.PhotoImage(image)


def make_inactive_image(
    template,
    power_available,
    extra_below_icon,
    show_power_charge_plus,
):
    gray = cv2.cvtColor(template, cv2.COLOR_BGR2GRAY)
    dim_gray = np.clip(gray.astype(np.float32) * 0.55 + 28, 0, 255).astype(np.uint8)
    dim = cv2.cvtColor(dim_gray, cv2.COLOR_GRAY2BGR)

    # Add an empty lower strip so active and inactive states have similar size.
    h, w = dim.shape[:2]
    # Transparency-key background in BGR, matching RGB #ff00ff.
    canvas = np.full(
        (h + extra_below_icon, w, 3),
        (255, 0, 255),
        dtype=np.uint8,
    )
    canvas[:h, :w] = dim
    cv2.rectangle(
        canvas,
        (0, 0),
        (w - 1, h - 1),
        (105, 105, 105),
        max(1, round(min(w, h) * 0.025)),
    )

    if power_available and show_power_charge_plus:
        # Green plus, positioned inside the icon artwork.
        thickness = max(2, round(min(w, h) * 0.08))
        arm = round(min(w, h) * 0.23)
        cx, cy = round(w * 0.72), round(h * 0.29)
        cv2.line(
            canvas, (cx - arm, cy), (cx + arm, cy), (0, 255, 0), thickness, cv2.LINE_AA
        )
        cv2.line(
            canvas, (cx, cy - arm), (cx, cy + arm), (0, 255, 0), thickness, cv2.LINE_AA
        )
    return canvas


class BuffOverlay:
    def __init__(self):
        self.app_settings = load_app_settings()
        self.cfg, self.templates = load_configuration()

        self.thresholds = self.cfg["thresholds"]

        self.thresholds["rend"] = self.app_settings["rend_threshold"]

        self.thresholds["power_charge"] = self.app_settings["power_charge_threshold"]
        self.misses_needed = self.app_settings["misses_before_gone"]

        self.root = tk.Tk()
        self.root.title("PoE Rend Overlay Prototype")
        self.root.overrideredirect(True)
        self.root.attributes("-topmost", True)
        self.root.configure(bg=TRANSPARENT_COLOUR)
        self.root.geometry(
            f'+{self.app_settings["overlay_x"]}' f'+{self.app_settings["overlay_y"]}'
        )

        self.frame = tk.Frame(
            self.root,
            bg=TRANSPARENT_COLOUR,
            highlightthickness=BORDER_WIDTH if SHOW_BORDER else 0,
            highlightbackground=BORDER_COLOUR,
        )
        self.frame.pack(padx=PADDING, pady=PADDING)
        self.label = tk.Label(self.frame, bg=TRANSPARENT_COLOUR, bd=0)
        self.label.pack()

        self.user_visible = True
        self.poe_context_visible = False
        self.overlay_actually_visible = False
        self.click_through = True
        self.photo = None
        self.sct = mss.MSS()

        self.state = {
            "rend": False,
            "power_charge": False,
        }
        self.misses = {
            "rend": 0,
            "power_charge": 0,
        }
        self.rend_box_client = None
        self.last_scores = {"rend": 0.0, "power_charge": 0.0}

        # Experimental HUD-anchor tracker state.
        self.hud_tracking_enabled = HUD_TRACKING_ENABLED
        self.hud_anchor_template = None
        self.hud_anchor_client = None
        self.hud_overlay_offset = None
        self.hud_last_score = 0.0
        self.hud_tracking_misses = 0
        self.hud_tracking_time_total_ms = 0.0
        self.hud_tracking_samples = 0
        self.hud_stats_started = time.perf_counter()

        self.root.bind("<Escape>", lambda _event: self.close())
        self.root.protocol("WM_DELETE_WINDOW", self.close)

        self.root.update_idletasks()
        self.apply_click_through(True)

        # Tk creates the top-level window as visible. Hide the actual Win32
        # window immediately so Python state and Windows state agree before
        # the first PoE-context check runs.
        win32gui.ShowWindow(
            self.overlay_hwnd(),
            0,  # SW_HIDE
        )
        self.overlay_actually_visible = False

        self.register_hotkeys()
        self.render_inactive()

        self.root.after(50, self.poll_hotkeys)
        self.root.after(100, self.detection_tick)
        self.root.after(100, self.display_tick)
        self.root.after(50, self.window_context_tick)
        self.root.after(250, self.hud_tracking_tick)

    def register_hotkeys(self):
        # Global key-state polling avoids installing keyboard hooks.
        self.key_latches = {
            win32con.VK_F8: False,
            win32con.VK_F9: False,
        }

    def poll_hotkeys(self):
        for key in self.key_latches:
            down = bool(win32api.GetAsyncKeyState(key) & 0x8000)
            if down and not self.key_latches[key]:
                if key == win32con.VK_F8:
                    self.toggle_visibility()
                elif key == win32con.VK_F9:
                    self.toggle_hud_tracking()
            self.key_latches[key] = down
        self.root.after(50, self.poll_hotkeys)

    def overlay_hwnd(self):
        """Return the real top-level Win32 HWND behind the Tk window."""
        self.root.update_idletasks()
        child = self.root.winfo_id()
        GA_ROOT = 2
        return win32gui.GetAncestor(child, GA_ROOT)

    def apply_click_through(self, enabled=True):
        """Apply transparency and click-through to the actual top-level HWND."""
        self.click_through = True
        hwnd = self.overlay_hwnd()
        style = win32gui.GetWindowLong(hwnd, win32con.GWL_EXSTYLE)
        style |= (
            win32con.WS_EX_LAYERED
            | win32con.WS_EX_TRANSPARENT
            | win32con.WS_EX_TOOLWINDOW
            | win32con.WS_EX_NOACTIVATE
        )
        style &= ~win32con.WS_EX_APPWINDOW
        win32gui.SetWindowLong(hwnd, win32con.GWL_EXSTYLE, style)

        # COLORREF layout is 0x00BBGGRR. Magenta #ff00ff therefore remains 0x00ff00ff.
        LWA_COLORKEY = 0x00000001
        win32gui.SetLayeredWindowAttributes(hwnd, 0x00FF00FF, 255, LWA_COLORKEY)
        win32gui.SetWindowPos(
            hwnd,
            win32con.HWND_TOPMOST,
            0,
            0,
            0,
            0,
            win32con.SWP_NOMOVE
            | win32con.SWP_NOSIZE
            | win32con.SWP_NOACTIVATE
            | win32con.SWP_FRAMECHANGED,
        )
        print(f"Click-through: ON | top-level HWND={hwnd}")

    def toggle_visibility(self):
        self.user_visible = not self.user_visible
        self.update_overlay_visibility()

        print(
            f"Overlay preference: " f'{"VISIBLE" if self.user_visible else "HIDDEN"}',
            flush=True,
        )

    def is_poe_context_allowed(self):
        hwnd = find_game_window()

        if not hwnd:
            return False

        if not win32gui.IsWindowVisible(hwnd):
            return False

        if win32gui.IsIconic(hwnd):
            return False

        if not self.app_settings["show_only_when_poe_active"]:
            return True

        return win32gui.GetForegroundWindow() == hwnd

    def update_overlay_visibility(self):
        should_show = self.user_visible and self.poe_context_visible

        hwnd = self.overlay_hwnd()
        currently_visible = bool(win32gui.IsWindowVisible(hwnd))

        if should_show == currently_visible:
            self.overlay_actually_visible = currently_visible
            return

        if should_show:
            # Display without taking focus away from PoE.
            SW_SHOWNOACTIVATE = 4

            win32gui.ShowWindow(
                hwnd,
                SW_SHOWNOACTIVATE,
            )

            self.root.attributes("-topmost", True)
            self.apply_click_through()

            self.overlay_actually_visible = True

            print(
                "Overlay shown for PoE context",
                flush=True,
            )
        else:
            SW_HIDE = 0

            win32gui.ShowWindow(
                hwnd,
                SW_HIDE,
            )

            self.overlay_actually_visible = False

            print(
                "Overlay hidden outside PoE context",
                flush=True,
            )

    def window_context_tick(self):
        try:
            self.poe_context_visible = self.is_poe_context_allowed()

            self.update_overlay_visibility()

        except Exception as exc:
            self.poe_context_visible = False
            self.update_overlay_visibility()

            print(
                f"Window-context warning: {exc}",
                flush=True,
            )

        finally:
            self.root.after(
                WINDOW_CHECK_INTERVAL_MS,
                self.window_context_tick,
            )

    def capture_client_roi(self, hwnd, roi):
        ox, oy = client_origin(hwnd)
        x, y, w, h = map(int, roi)
        raw = np.asarray(
            self.sct.grab({"left": ox + x, "top": oy + y, "width": w, "height": h})
        )
        return cv2.cvtColor(raw, cv2.COLOR_BGRA2BGR)

    def toggle_hud_tracking(self):
        self.hud_tracking_enabled = not self.hud_tracking_enabled

        if self.hud_tracking_enabled:
            self.reset_hud_tracker()
        else:
            self.move_overlay_to_fixed_position()

        print(
            "Experimental HUD anchoring:",
            "ON" if self.hud_tracking_enabled else "OFF",
            flush=True,
        )

    def reset_hud_tracker(self):
        self.hud_anchor_template = None
        self.hud_anchor_client = None
        self.hud_overlay_offset = None
        self.hud_last_score = 0.0
        self.hud_tracking_misses = 0

    def move_overlay_to_fixed_position(self):
        hwnd = self.overlay_hwnd()
        win32gui.SetWindowPos(
            hwnd,
            win32con.HWND_TOPMOST,
            self.app_settings["overlay_x"],
            self.app_settings["overlay_y"],
            0,
            0,
            win32con.SWP_NOSIZE | win32con.SWP_NOACTIVATE,
        )

    @staticmethod
    def hud_edge_image(image):
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        return cv2.Canny(gray, 45, 120)

    def initialize_hud_tracker(self, hwnd):
        origin_x, origin_y = client_origin(hwnd)
        client_width, client_height = client_size(hwnd)

        overlay_client_x = self.app_settings["overlay_x"] - origin_x
        overlay_client_y = self.app_settings["overlay_y"] - origin_y

        anchor_x = overlay_client_x - HUD_ANCHOR_GAP - HUD_ANCHOR_WIDTH
        anchor_y = overlay_client_y + HUD_ANCHOR_Y_OFFSET

        if (
            anchor_x < 0
            or anchor_y < 0
            or anchor_x + HUD_ANCHOR_WIDTH > client_width
            or anchor_y + HUD_ANCHOR_HEIGHT > client_height
        ):
            return False

        anchor = self.capture_client_roi(
            hwnd,
            (anchor_x, anchor_y, HUD_ANCHOR_WIDTH, HUD_ANCHOR_HEIGHT),
        )
        template = self.hud_edge_image(anchor)

        # A nearly empty edge template is not distinctive enough to track.
        if cv2.countNonZero(template) < 20:
            return False

        self.hud_anchor_template = template
        self.hud_anchor_client = (anchor_x, anchor_y)
        self.hud_overlay_offset = (
            overlay_client_x - anchor_x,
            overlay_client_y - anchor_y,
        )
        self.hud_tracking_misses = 0

        print(
            "HUD anchor initialized at",
            self.hud_anchor_client,
            flush=True,
        )
        return True

    def move_overlay_with_anchor(self, hwnd, anchor_x, anchor_y):
        origin_x, origin_y = client_origin(hwnd)
        offset_x, offset_y = self.hud_overlay_offset
        target_x = round(origin_x + anchor_x + offset_x)
        target_y = round(origin_y + anchor_y + offset_y)

        left, top, _, _ = win32gui.GetWindowRect(self.overlay_hwnd())
        if (
            abs(target_x - left) <= HUD_POSITION_DEAD_ZONE
            and abs(target_y - top) <= HUD_POSITION_DEAD_ZONE
        ):
            return

        win32gui.SetWindowPos(
            self.overlay_hwnd(),
            win32con.HWND_TOPMOST,
            target_x,
            target_y,
            0,
            0,
            win32con.SWP_NOSIZE | win32con.SWP_NOACTIVATE,
        )

    def print_hud_tracking_stats(self):
        now = time.perf_counter()
        elapsed = now - self.hud_stats_started
        if elapsed < HUD_STATS_INTERVAL_SECONDS:
            return

        average_ms = (
            self.hud_tracking_time_total_ms / self.hud_tracking_samples
            if self.hud_tracking_samples
            else 0.0
        )
        print(
            f"HUD tracking score={self.hud_last_score:.3f} "
            f"avg={average_ms:.2f}ms "
            f"misses={self.hud_tracking_misses}",
            flush=True,
        )
        self.hud_tracking_time_total_ms = 0.0
        self.hud_tracking_samples = 0
        self.hud_stats_started = now

    def hud_tracking_tick(self):
        started = time.perf_counter()
        try:
            if not self.hud_tracking_enabled or not self.poe_context_visible:
                return

            hwnd = find_game_window()
            if not hwnd or win32gui.IsIconic(hwnd):
                return

            if self.hud_anchor_template is None:
                self.initialize_hud_tracker(hwnd)
                return

            anchor_x, anchor_y = self.hud_anchor_client
            client_width, client_height = client_size(hwnd)

            search_x = max(0, anchor_x - HUD_SEARCH_MARGIN)
            search_y = max(0, anchor_y - HUD_SEARCH_MARGIN)
            search_right = min(
                client_width,
                anchor_x + HUD_ANCHOR_WIDTH + HUD_SEARCH_MARGIN,
            )
            search_bottom = min(
                client_height,
                anchor_y + HUD_ANCHOR_HEIGHT + HUD_SEARCH_MARGIN,
            )
            search_width = search_right - search_x
            search_height = search_bottom - search_y

            search = self.capture_client_roi(
                hwnd,
                (search_x, search_y, search_width, search_height),
            )
            search_edges = self.hud_edge_image(search)
            response = cv2.matchTemplate(
                search_edges,
                self.hud_anchor_template,
                cv2.TM_CCOEFF_NORMED,
            )
            _, score, _, location = cv2.minMaxLoc(response)
            self.hud_last_score = float(score)

            if score >= HUD_MATCH_THRESHOLD:
                found_x = search_x + location[0]
                found_y = search_y + location[1]
                self.hud_anchor_client = (found_x, found_y)
                self.hud_tracking_misses = 0
                self.move_overlay_with_anchor(hwnd, found_x, found_y)
            else:
                self.hud_tracking_misses += 1

                # A fresh template is safer than following a weak match.
                if self.hud_tracking_misses >= 20:
                    self.move_overlay_to_fixed_position()
                    self.reset_hud_tracker()

        except Exception as exc:
            print(f"HUD tracking warning: {exc}", flush=True)
        finally:
            elapsed_ms = (time.perf_counter() - started) * 1000.0
            self.hud_tracking_time_total_ms += elapsed_ms
            self.hud_tracking_samples += 1
            self.print_hud_tracking_stats()
            self.root.after(HUD_TRACKING_INTERVAL_MS, self.hud_tracking_tick)

    def detection_tick(self):
        try:
            if not self.poe_context_visible:
                return

            hwnd = find_game_window()
            if hwnd and win32gui.IsWindowVisible(hwnd):
                rx, ry, rw, rh = map(int, self.cfg["search_roi"])
                search = self.capture_client_roi(hwnd, (rx, ry, rw, rh))

                for name, template in self.templates.items():
                    score, (mx, my) = match_template(search, template)
                    self.last_scores[name] = score
                    raw_found = score >= float(self.thresholds[name])

                    if raw_found:
                        self.misses[name] = 0
                        self.state[name] = True
                        if name == "rend":
                            th, tw = template.shape[:2]
                            self.rend_box_client = (rx + mx, ry + my, tw, th)
                    else:
                        self.misses[name] += 1
                        if self.misses[name] >= self.misses_needed:
                            self.state[name] = False
                            if name == "rend":
                                self.rend_box_client = None

                print(
                    time.strftime("%H:%M:%S"),
                    f'rend={"ON" if self.state["rend"] else "off"} ({self.last_scores["rend"]:.3f})',
                    f'charge={"ON" if self.state["power_charge"] else "off"} ({self.last_scores["power_charge"]:.3f})',
                    flush=True,
                )
        except Exception as exc:
            print(f"Detection warning: {exc}", flush=True)
        finally:
            self.root.after(
                self.app_settings["detection_interval_ms"],
                self.detection_tick,
            )

    def display_tick(self):
        try:
            if not self.poe_context_visible:
                return

            hwnd = find_game_window()
            if (
                self.state["rend"]
                and self.rend_box_client
                and hwnd
                and not win32gui.IsIconic(hwnd)
            ):
                x, y, w, h = self.rend_box_client
                cw, ch = client_size(hwnd)
                extra = max(
                    0,
                    min(
                        self.app_settings["extra_below_icon"],
                        ch - (y + h),
                    ),
                )
                live = self.capture_client_roi(hwnd, (x, y, w, h + extra))
                self.show_image(live)
            else:
                self.render_inactive()
        except Exception as exc:
            print(f"Display warning: {exc}", flush=True)
            self.render_inactive()
        finally:
            self.root.after(
                self.app_settings["display_interval_ms"],
                self.display_tick,
            )

    def render_inactive(self):
        image = make_inactive_image(
            self.templates["rend"],
            self.state["power_charge"],
            self.app_settings["extra_below_icon"],
            self.app_settings["show_power_charge_plus"],
        )
        self.show_image(image)

    def show_image(self, image):
        self.photo = bgr_to_photo(
            image,
            self.app_settings["scale"],
        )
        self.label.configure(image=self.photo)

    def close(self):
        try:
            self.sct.close()
        except Exception:
            pass
        self.root.destroy()

    def run(self):
        print(f"PoE Rend overlay v{VERSION} started.")
        print(
            "F8 = show/hide | F9 = toggle HUD anchoring | Esc = exit | "
            "Overlay is permanently click-through"
        )
        print(
            "v1.7 experimental: local 60 Hz HUD-anchor matching with "
            "five-second tracking-cost reports."
        )
        self.root.mainloop()


if __name__ == "__main__":
    BuffOverlay().run()
