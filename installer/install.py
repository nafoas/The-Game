"""
Hunt Down Joe Biden — Installer v1.0
Checks prerequisites, clones the game repo (with all LFS assets),
downloads Godot 4.4, creates a launcher and desktop shortcut.
"""

import sys, os, shutil, subprocess, threading, platform, urllib.request
import zipfile, time, ctypes
from pathlib import Path

import tkinter as tk
from tkinter import ttk, messagebox, filedialog

# ── Constants ─────────────────────────────────────────────────────────────────
GAME_TITLE    = "Hunt Down Joe Biden"
REPO_URL      = "https://github.com/nafoas/the-game.git"
REPO_BRANCH   = "main"
GODOT_VER     = "4.4"
GODOT_URL_WIN = (
    "https://github.com/godotengine/godot/releases/download/"
    f"{GODOT_VER}-stable/Godot_v{GODOT_VER}-stable_win64.exe.zip"
)
GODOT_URL_LIN = (
    "https://github.com/godotengine/godot/releases/download/"
    f"{GODOT_VER}-stable/Godot_v{GODOT_VER}-stable_linux.x86_64.zip"
)
GODOT_URL_MAC = (
    "https://github.com/godotengine/godot/releases/download/"
    f"{GODOT_VER}-stable/Godot_v{GODOT_VER}-stable_macos.universal.zip"
)
GIT_INSTALL_URL = "https://git-scm.com/download/win"
LFS_INSTALL_URL = "https://git-lfs.github.com/"
DEFAULT_DIR_WIN = str(Path.home() / "Games" / "HuntDownJoeBiden")
DEFAULT_DIR_LIN = str(Path.home() / "Games" / "HuntDownJoeBiden")
DEFAULT_DIR_MAC = str(Path.home() / "Applications" / "HuntDownJoeBiden")

IS_WIN = platform.system() == "Windows"
IS_MAC = platform.system() == "Darwin"

BG      = "#111111"
BG2     = "#1c1c1c"
BG3     = "#242424"
ORANGE  = "#ff9e1b"
ORANGE2 = "#ffb84d"
WHITE   = "#e8e8e8"
GREY    = "#888888"
GREY2   = "#444444"
RED     = "#e05555"
GREEN   = "#55cc55"
BLUE    = "#5599dd"

WIN_W, WIN_H = 800, 520


# ═══════════════════════════════════════════════════════════════════════════════
class Installer(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title(f"{GAME_TITLE} — Installer")
        self.resizable(False, False)
        self.configure(bg=BG)
        self._center(WIN_W, WIN_H)

        self._install_dir = tk.StringVar(value=self._default_dir())
        self._installing  = False

        self._build_ui()
        self.after(50, self._check_prereqs)

    # ── Layout ─────────────────────────────────────────────────────────────────
    def _build_ui(self):
        # ── Orange top bar ────────────────────────────────────────────────────
        topbar = tk.Frame(self, bg=ORANGE, height=4)
        topbar.pack(side="top", fill="x")

        # ── BOTTOM bar — packed FIRST so it's always visible ──────────────────
        bottom = tk.Frame(self, bg=BG2, padx=24, pady=12)
        bottom.pack(side="bottom", fill="x")

        self._install_btn = tk.Button(
            bottom, text="Install & Play",
            font=("Segoe UI", 11, "bold"), bg=ORANGE, fg=BG,
            activebackground=ORANGE2, activeforeground=BG,
            relief="flat", bd=0, padx=24, pady=8,
            cursor="hand2", command=self._start_install)
        self._install_btn.pack(side="right")

        tk.Button(bottom, text="Cancel",
                  font=("Segoe UI", 9), bg=BG2, fg=GREY,
                  activebackground=BG3, activeforeground=WHITE,
                  relief="flat", bd=0, padx=10, pady=8,
                  cursor="hand2", command=self.destroy
                  ).pack(side="right", padx=(0, 8))

        self._status_var = tk.StringVar(value="Checking requirements…")
        tk.Label(bottom, textvariable=self._status_var,
                 font=("Segoe UI", 8), fg=GREY, bg=BG2,
                 anchor="w").pack(side="left", fill="x", expand=True)

        # ── Progress bar (between bottom bar and content) ─────────────────────
        bar_frame = tk.Frame(self, bg=BG, padx=24, pady=0)
        bar_frame.pack(side="bottom", fill="x")
        self._bar = ttk.Progressbar(bar_frame, mode="indeterminate", length=WIN_W)
        self._bar.pack(fill="x")
        style = ttk.Style(self)
        style.theme_use("default")
        style.configure("TProgressbar", troughcolor=BG2,
                        background=ORANGE, thickness=5)

        # ── Scrollable main content ───────────────────────────────────────────
        outer = tk.Frame(self, bg=BG)
        outer.pack(side="top", fill="both", expand=True)

        canvas = tk.Canvas(outer, bg=BG, highlightthickness=0, bd=0)
        scrollbar = tk.Scrollbar(outer, orient="vertical", command=canvas.yview)
        canvas.configure(yscrollcommand=scrollbar.set)

        scrollbar.pack(side="right", fill="y")
        canvas.pack(side="left", fill="both", expand=True)

        self._scroll_frame = tk.Frame(canvas, bg=BG)
        self._canvas_window = canvas.create_window(
            (0, 0), window=self._scroll_frame, anchor="nw")

        def _on_frame_configure(e):
            canvas.configure(scrollregion=canvas.bbox("all"))
        def _on_canvas_configure(e):
            canvas.itemconfig(self._canvas_window, width=e.width)
        self._scroll_frame.bind("<Configure>", _on_frame_configure)
        canvas.bind("<Configure>", _on_canvas_configure)

        def _on_mousewheel(e):
            canvas.yview_scroll(int(-1 * (e.delta / 120)), "units")
        canvas.bind_all("<MouseWheel>", _on_mousewheel)

        self._build_content(self._scroll_frame)

    def _build_content(self, parent):
        pad = dict(padx=28)

        # Header ──────────────────────────────────────────────────────────────
        hdr = tk.Frame(parent, bg=BG)
        hdr.pack(fill="x", pady=(20, 14), **pad)
        tk.Label(hdr, text=GAME_TITLE, font=("Segoe UI", 22, "bold"),
                 fg=ORANGE, bg=BG, anchor="w").pack(fill="x")
        tk.Label(hdr, text="A Half-Life 2 parody FPS  •  Installer v1.0",
                 font=("Segoe UI", 9), fg=GREY, bg=BG, anchor="w").pack(fill="x")

        tk.Frame(parent, bg=GREY2, height=1).pack(fill="x", **pad)

        # Requirements ────────────────────────────────────────────────────────
        self._section(parent, "REQUIREMENTS")

        req = tk.Frame(parent, bg=BG2, padx=16, pady=10)
        req.pack(fill="x", pady=(4, 12), **pad)

        self._git_icon   = tk.Label(req, text="○", font=("Segoe UI", 12), fg=GREY, bg=BG2, width=2)
        self._git_status = tk.Label(req, text="Checking…", font=("Consolas", 10), fg=GREY, bg=BG2, anchor="w")
        self._lfs_icon   = tk.Label(req, text="○", font=("Segoe UI", 12), fg=GREY, bg=BG2, width=2)
        self._lfs_status = tk.Label(req, text="Checking…", font=("Consolas", 10), fg=GREY, bg=BG2, anchor="w")

        self._req_row(req, self._git_icon, "Git",     self._git_status, GIT_INSTALL_URL, 0)
        self._req_row(req, self._lfs_icon, "Git LFS", self._lfs_status, LFS_INSTALL_URL, 1)

        # Install location ────────────────────────────────────────────────────
        self._section(parent, "INSTALL LOCATION")

        loc = tk.Frame(parent, bg=BG2, padx=16, pady=10)
        loc.pack(fill="x", pady=(4, 12), **pad)

        row = tk.Frame(loc, bg=BG2)
        row.pack(fill="x")
        tk.Entry(row, textvariable=self._install_dir, font=("Consolas", 10),
                 bg=BG3, fg=WHITE, insertbackground=WHITE, relief="flat", bd=0,
                 highlightthickness=1, highlightbackground=GREY2,
                 highlightcolor=ORANGE).pack(side="left", fill="x", expand=True, ipady=5, ipadx=4)
        tk.Button(row, text="Browse…", font=("Segoe UI", 9),
                  bg=BG3, fg=WHITE, activebackground=ORANGE, activeforeground=BG,
                  relief="flat", bd=0, padx=8, pady=5, cursor="hand2",
                  command=self._browse).pack(side="right", padx=(6, 0))
        tk.Label(loc, text="~3 GB downloaded (game assets + Godot engine)",
                 font=("Segoe UI", 8), fg=GREY, bg=BG2, anchor="w").pack(fill="x", pady=(5, 0))

        # Steps ───────────────────────────────────────────────────────────────
        self._section(parent, "INSTALL STEPS")

        steps_frame = tk.Frame(parent, bg=BG2, padx=16, pady=10)
        steps_frame.pack(fill="x", pady=(4, 16), **pad)

        step_names = [
            "Clone game repository (~3 GB)",
            f"Download Godot {GODOT_VER}",
            "Extract Godot",
            "Create launcher & desktop shortcut",
        ]
        self._step_icons  = []
        self._step_labels = []
        for i, name in enumerate(step_names):
            icon = tk.Label(steps_frame, text="○", font=("Segoe UI", 11),
                            fg=GREY2, bg=BG2, width=2)
            icon.grid(row=i, column=0, sticky="w", pady=2)
            lbl = tk.Label(steps_frame, text=name, font=("Segoe UI", 10),
                           fg=GREY, bg=BG2, anchor="w")
            lbl.grid(row=i, column=1, sticky="w", pady=2)
            self._step_icons.append(icon)
            self._step_labels.append(lbl)

    def _section(self, parent, text):
        tk.Label(parent, text=text, font=("Segoe UI", 8, "bold"),
                 fg=GREY, bg=BG, anchor="w").pack(fill="x", padx=28)

    def _req_row(self, parent, icon, label, status_lbl, url, row):
        icon.grid(row=row, column=0, sticky="w", pady=(0 if row else 0, 4 if row == 0 else 0))
        tk.Label(parent, text=f"{label:<10}", font=("Consolas", 10),
                 fg=WHITE, bg=BG2, anchor="w", width=10).grid(
            row=row, column=1, sticky="w")
        status_lbl.grid(row=row, column=2, sticky="w", padx=(4, 16))
        link = tk.Label(parent, text=f"Download {label} ↗", font=("Segoe UI", 8),
                        fg=BLUE, bg=BG2, cursor="hand2")
        link.grid(row=row, column=3, sticky="w")
        link.bind("<Button-1>", lambda *_: self._open_url(url))

    # ── Prereq detection ───────────────────────────────────────────────────────
    def _check_prereqs(self):
        def _run():
            git_ok = shutil.which("git") is not None
            lfs_ok = False
            if git_ok:
                try:
                    r = subprocess.run(["git", "lfs", "version"],
                                       capture_output=True, timeout=5)
                    lfs_ok = r.returncode == 0
                except Exception:
                    pass
            self.after(0, lambda: self._apply_prereq_results(git_ok, lfs_ok))
        threading.Thread(target=_run, daemon=True).start()

    def _apply_prereq_results(self, git_ok: bool, lfs_ok: bool):
        if git_ok:
            self._git_icon.configure(text="✓", fg=GREEN)
            self._git_status.configure(text="Found", fg=GREEN)
        else:
            self._git_icon.configure(text="✗", fg=RED)
            self._git_status.configure(text="Not found", fg=RED)

        if lfs_ok:
            self._lfs_icon.configure(text="✓", fg=GREEN)
            self._lfs_status.configure(text="Found", fg=GREEN)
        else:
            self._lfs_icon.configure(text="✗", fg=RED)
            self._lfs_status.configure(text="Not found", fg=RED)

        if git_ok and lfs_ok:
            self._status_var.set("Ready to install.")
        else:
            missing = []
            if not git_ok: missing.append("Git")
            if not lfs_ok: missing.append("Git LFS")
            self._status_var.set(f"Install {', '.join(missing)} first — links above.")
            self._install_btn.configure(
                bg=GREY2, fg=GREY,
                text=f"Missing: {', '.join(missing)}",
                command=lambda: messagebox.showinfo(
                    "Prerequisites required",
                    "Please install the following, then re-run the installer:\n\n"
                    f"  Git:     {GIT_INSTALL_URL}\n"
                    f"  Git LFS: {LFS_INSTALL_URL}"))

    # ── Install flow ───────────────────────────────────────────────────────────
    def _start_install(self):
        if self._installing:
            return
        self._installing = True
        dest = Path(self._install_dir.get()).resolve()
        self._install_btn.configure(state="disabled", bg=GREY2, fg=GREY, text="Installing…")
        self._bar.start(10)
        threading.Thread(target=self._install_thread, args=(dest,), daemon=True).start()

    def _install_thread(self, dest: Path):
        def ui(fn): self.after(0, fn)
        try:
            dest.mkdir(parents=True, exist_ok=True)
            game_dir = dest / "game"

            ui(lambda: self._step_start(0, "Cloning repository — may take 10–20 min…"))
            if game_dir.exists():
                shutil.rmtree(game_dir)
            subprocess.run(["git", "clone", "--branch", REPO_BRANCH,
                            "--progress", REPO_URL, str(game_dir)], check=True)
            subprocess.run(["git", "lfs", "pull"], cwd=game_dir, check=True)
            ui(lambda: self._step_done(0))

            ui(lambda: self._step_start(1, f"Downloading Godot {GODOT_VER}…"))
            godot_dir = dest / "godot"
            godot_dir.mkdir(exist_ok=True)
            godot_zip = godot_dir / "godot.zip"
            url = GODOT_URL_WIN if IS_WIN else (GODOT_URL_MAC if IS_MAC else GODOT_URL_LIN)
            self._download(url, godot_zip)
            ui(lambda: self._step_done(1))

            ui(lambda: self._step_start(2, "Extracting Godot…"))
            with zipfile.ZipFile(godot_zip, "r") as z:
                z.extractall(godot_dir)
            godot_zip.unlink(missing_ok=True)
            godot_exe = self._find_godot_binary(godot_dir)
            ui(lambda: self._step_done(2))

            ui(lambda: self._step_start(3, "Creating launcher and shortcut…"))
            if IS_WIN:
                launcher = dest / "Play Hunt Down Joe Biden.bat"
                launcher.write_text(
                    f'@echo off\nstart "" "{godot_exe}" --path "{game_dir}"\n',
                    encoding="utf-8")
                self._create_shortcut(GAME_TITLE, str(launcher),
                                      str(game_dir / "icon.svg"), str(dest))
            else:
                launcher = dest / "play.sh"
                launcher.write_text(f'#!/bin/sh\n"{godot_exe}" --path "{game_dir}"\n',
                                    encoding="utf-8")
                launcher.chmod(0o755)
            ui(lambda: self._step_done(3))

            def _finish():
                self._bar.stop()
                self._bar.configure(mode="determinate")
                self._bar["value"] = 100
                self._status_var.set("Installation complete!")
                self._install_btn.configure(
                    state="normal", bg=GREEN, fg=BG,
                    text="Play Now!", command=lambda: self._launch(launcher))
            ui(_finish)

        except subprocess.CalledProcessError as e:
            ui(lambda: self._fail(f"Command failed:\n{e}"))
        except Exception as e:
            msg = str(e)
            ui(lambda: self._fail(msg))

    # ── Step helpers (main-thread only) ────────────────────────────────────────
    def _step_start(self, idx, status):
        self._step_icons[idx].configure(text="▶", fg=ORANGE)
        self._step_labels[idx].configure(fg=WHITE)
        self._status_var.set(status)

    def _step_done(self, idx):
        self._step_icons[idx].configure(text="✓", fg=GREEN)
        self._step_labels[idx].configure(fg=GREEN)

    # ── Misc helpers ───────────────────────────────────────────────────────────
    def _download(self, url, dest):
        tmp = str(dest) + ".part"
        def _progress(count, block, total):
            if total > 0:
                pct = min(int(count * block * 100 / total), 100)
                mb  = count * block / 1_048_576
                msg = f"Downloading Godot {GODOT_VER}…  {mb:.1f} MB  ({pct}%)"
                self.after(0, lambda m=msg: self._status_var.set(m))
        urllib.request.urlretrieve(url, tmp, reporthook=_progress)
        os.replace(tmp, dest)

    def _find_godot_binary(self, godot_dir):
        exts = [".exe"] if IS_WIN else ([""] if not IS_MAC else [".app/Contents/MacOS/Godot"])
        for f in godot_dir.rglob("*"):
            name = f.name.lower()
            if "godot" in name and any(name.endswith(e) for e in exts):
                return f
        for f in godot_dir.iterdir():
            if f.is_file() and os.access(f, os.X_OK):
                return f
        raise FileNotFoundError("Could not find Godot binary after extraction.")

    def _create_shortcut(self, name, target, icon, work_dir):
        try:
            desktop = Path.home() / "Desktop"
            if not desktop.exists():
                return
            ps = (f'$ws = New-Object -ComObject WScript.Shell; '
                  f'$s = $ws.CreateShortcut("{desktop / (name + ".lnk")}"); '
                  f'$s.TargetPath = "{target}"; '
                  f'$s.WorkingDirectory = "{work_dir}"; $s.Save()')
            subprocess.run(["powershell", "-NoProfile", "-Command", ps], capture_output=True)
        except Exception:
            pass

    def _launch(self, launcher):
        try:
            if IS_WIN: os.startfile(str(launcher))
            else:      subprocess.Popen([str(launcher)])
        except Exception:
            pass
        self.destroy()

    def _fail(self, msg):
        self._bar.stop()
        self._installing = False
        self._status_var.set("Installation failed.")
        self._install_btn.configure(state="normal", bg=RED, fg=WHITE,
                                    text="Retry", command=self._start_install)
        messagebox.showerror("Installation failed", msg)

    def _browse(self):
        d = filedialog.askdirectory(title="Choose install location")
        if d:
            self._install_dir.set(d)

    @staticmethod
    def _default_dir():
        if IS_WIN: return DEFAULT_DIR_WIN
        if IS_MAC: return DEFAULT_DIR_MAC
        return DEFAULT_DIR_LIN

    @staticmethod
    def _open_url(url):
        import webbrowser
        webbrowser.open(url)

    def _center(self, w, h):
        self.update_idletasks()
        x = (self.winfo_screenwidth()  - w) // 2
        y = (self.winfo_screenheight() - h) // 2
        self.geometry(f"{w}x{h}+{x}+{y}")


# ═══════════════════════════════════════════════════════════════════════════════
if __name__ == "__main__":
    if IS_WIN and not ctypes.windll.shell32.IsUserAnAdmin():
        ctypes.windll.shell32.ShellExecuteW(
            None, "runas", sys.executable, " ".join(sys.argv), None, 1)
        sys.exit()
    app = Installer()
    app.mainloop()
