"""
Hunt Down Joe Biden — Installer v1.0
Checks prerequisites, clones the game repo (with all LFS assets),
downloads Godot 4.4, creates a launcher and desktop shortcut.
"""

import sys, os, shutil, subprocess, threading, platform, urllib.request
import zipfile, tempfile, time, ctypes
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

# ── Colour palette ─────────────────────────────────────────────────────────────
BG      = "#111111"
BG2     = "#1e1e1e"
BG3     = "#282828"
ORANGE  = "#ff9e1b"
ORANGE2 = "#ffb84d"
WHITE   = "#e8e8e8"
GREY    = "#888888"
GREY2   = "#555555"
RED     = "#e05555"
GREEN   = "#55cc55"
BLUE    = "#5599dd"

FONT_TITLE  = ("Segoe UI", 26, "bold")
FONT_SUB    = ("Segoe UI", 10)
FONT_LABEL  = ("Segoe UI", 10)
FONT_MONO   = ("Consolas", 10)
FONT_BTN    = ("Segoe UI", 11, "bold")
FONT_SMALL  = ("Segoe UI", 9)

WIN_W, WIN_H = 860, 600


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

        # Step tracking (main-thread only, touched via after())
        self._steps: list[dict] = []

        self._build_ui()
        # Kick prereq check after UI is drawn
        self.after(50, self._check_prereqs)

    # ── Layout ─────────────────────────────────────────────────────────────────
    def _build_ui(self):
        # ── Left sidebar ──────────────────────────────────────────────────────
        sidebar = tk.Frame(self, bg=ORANGE, width=14)
        sidebar.pack(side="left", fill="y")
        sidebar.pack_propagate(False)

        # ── Main area ─────────────────────────────────────────────────────────
        main = tk.Frame(self, bg=BG, padx=36, pady=0)
        main.pack(side="left", fill="both", expand=True)

        # Header
        hdr = tk.Frame(main, bg=BG, pady=28)
        hdr.pack(fill="x")
        tk.Label(hdr, text=GAME_TITLE, font=FONT_TITLE,
                 fg=ORANGE, bg=BG, anchor="w").pack(fill="x")
        tk.Label(hdr, text="A Half-Life 2 parody FPS  •  Installer v1.0",
                 font=FONT_SUB, fg=GREY, bg=BG, anchor="w").pack(fill="x")

        tk.Frame(main, bg=GREY2, height=1).pack(fill="x", pady=(0, 20))

        # ── Requirements section ───────────────────────────────────────────────
        tk.Label(main, text="REQUIREMENTS", font=("Segoe UI", 8, "bold"),
                 fg=GREY, bg=BG, anchor="w").pack(fill="x")

        req_frame = tk.Frame(main, bg=BG2, pady=14, padx=18)
        req_frame.pack(fill="x", pady=(6, 18))

        self._git_icon = tk.Label(req_frame, text="○", font=("Segoe UI", 13),
                                  fg=GREY, bg=BG2, width=2)
        self._git_icon.grid(row=0, column=0, sticky="w")
        tk.Label(req_frame, text="Git", font=FONT_LABEL,
                 fg=WHITE, bg=BG2, anchor="w", width=10).grid(row=0, column=1, sticky="w")
        self._git_status = tk.Label(req_frame, text="Checking…", font=FONT_MONO,
                                    fg=GREY, bg=BG2, anchor="w")
        self._git_status.grid(row=0, column=2, sticky="w", padx=(0, 20))
        link_git = tk.Label(req_frame, text="Download Git ↗", font=FONT_SMALL,
                            fg=BLUE, bg=BG2, cursor="hand2")
        link_git.grid(row=0, column=3, sticky="w")
        link_git.bind("<Button-1>", lambda *_: self._open_url(GIT_INSTALL_URL))

        self._lfs_icon = tk.Label(req_frame, text="○", font=("Segoe UI", 13),
                                  fg=GREY, bg=BG2, width=2)
        self._lfs_icon.grid(row=1, column=0, sticky="w", pady=(8, 0))
        tk.Label(req_frame, text="Git LFS", font=FONT_LABEL,
                 fg=WHITE, bg=BG2, anchor="w", width=10).grid(row=1, column=1, sticky="w", pady=(8, 0))
        self._lfs_status = tk.Label(req_frame, text="Checking…", font=FONT_MONO,
                                    fg=GREY, bg=BG2, anchor="w")
        self._lfs_status.grid(row=1, column=2, sticky="w", pady=(8, 0), padx=(0, 20))
        link_lfs = tk.Label(req_frame, text="Download Git LFS ↗", font=FONT_SMALL,
                            fg=BLUE, bg=BG2, cursor="hand2")
        link_lfs.grid(row=1, column=3, sticky="w", pady=(8, 0))
        link_lfs.bind("<Button-1>", lambda *_: self._open_url(LFS_INSTALL_URL))

        # ── Install location ───────────────────────────────────────────────────
        tk.Label(main, text="INSTALL LOCATION", font=("Segoe UI", 8, "bold"),
                 fg=GREY, bg=BG, anchor="w").pack(fill="x")

        loc_frame = tk.Frame(main, bg=BG2, pady=12, padx=18)
        loc_frame.pack(fill="x", pady=(6, 18))

        entry_row = tk.Frame(loc_frame, bg=BG2)
        entry_row.pack(fill="x")
        tk.Entry(entry_row, textvariable=self._install_dir, font=FONT_MONO,
                 bg=BG3, fg=WHITE, insertbackground=WHITE, relief="flat",
                 bd=0, highlightthickness=1, highlightbackground=GREY2,
                 highlightcolor=ORANGE).pack(side="left", fill="x", expand=True,
                                             ipady=6, ipadx=6)
        tk.Button(entry_row, text="Browse…", font=FONT_SMALL,
                  bg=BG3, fg=WHITE, activebackground=ORANGE, activeforeground=BG,
                  relief="flat", bd=0, padx=10, pady=6,
                  cursor="hand2",
                  command=self._browse).pack(side="right", padx=(8, 0))

        tk.Label(loc_frame,
                 text="~3 GB will be downloaded (game assets + Godot engine)",
                 font=FONT_SMALL, fg=GREY, bg=BG2, anchor="w").pack(fill="x", pady=(6, 0))

        # ── Progress / steps ───────────────────────────────────────────────────
        tk.Label(main, text="PROGRESS", font=("Segoe UI", 8, "bold"),
                 fg=GREY, bg=BG, anchor="w").pack(fill="x")

        steps_outer = tk.Frame(main, bg=BG2, pady=10, padx=18)
        steps_outer.pack(fill="x", pady=(6, 0))

        step_names = [
            "Clone game repository (~3 GB)",
            f"Download Godot {GODOT_VER}",
            "Extract Godot",
            "Create launcher & shortcut",
        ]
        self._step_icons  = []
        self._step_labels = []
        for i, name in enumerate(step_names):
            icon = tk.Label(steps_outer, text="○", font=("Segoe UI", 11),
                            fg=GREY2, bg=BG2, width=2)
            icon.grid(row=i, column=0, sticky="w", pady=3)
            lbl = tk.Label(steps_outer, text=name, font=FONT_LABEL,
                           fg=GREY, bg=BG2, anchor="w")
            lbl.grid(row=i, column=1, sticky="w", pady=3)
            self._step_icons.append(icon)
            self._step_labels.append(lbl)

        # Status bar
        status_frame = tk.Frame(main, bg=BG, pady=10)
        status_frame.pack(fill="x")
        self._status_var = tk.StringVar(value="Checking requirements…")
        self._status_lbl = tk.Label(status_frame, textvariable=self._status_var,
                                    font=FONT_SMALL, fg=GREY, bg=BG, anchor="w")
        self._status_lbl.pack(fill="x")
        self._bar = ttk.Progressbar(status_frame, mode="indeterminate", length=WIN_W - 100)
        self._bar.pack(fill="x", pady=(4, 0))
        style = ttk.Style(self)
        style.theme_use("default")
        style.configure("TProgressbar", troughcolor=BG2,
                        background=ORANGE, thickness=6)

        # ── Bottom bar ─────────────────────────────────────────────────────────
        bottom = tk.Frame(self, bg=BG3, padx=36, pady=14)
        bottom.pack(side="bottom", fill="x")

        self._install_btn = tk.Button(
            bottom, text="Install & Play",
            font=FONT_BTN, bg=ORANGE, fg=BG,
            activebackground=ORANGE2, activeforeground=BG,
            relief="flat", bd=0, padx=28, pady=10,
            cursor="hand2",
            command=self._start_install)
        self._install_btn.pack(side="right")

        tk.Button(bottom, text="Cancel",
                  font=FONT_SMALL, bg=BG3, fg=GREY,
                  activebackground=BG2, activeforeground=WHITE,
                  relief="flat", bd=0, padx=12, pady=10,
                  cursor="hand2",
                  command=self.destroy).pack(side="right", padx=(0, 12))

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
            # Marshal results back to the main thread
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
            self._install_btn.configure(state="normal", bg=ORANGE, fg=BG,
                                        text="Install & Play",
                                        command=self._start_install)
        else:
            missing = []
            if not git_ok:  missing.append("Git")
            if not lfs_ok:  missing.append("Git LFS")
            self._status_var.set(f"Install {', '.join(missing)} then re-run this installer.")
            self._install_btn.configure(
                state="normal", bg=GREY2, fg=GREY,
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
        self._install_btn.configure(state="disabled", bg=GREY2, fg=GREY,
                                    text="Installing…")
        self._bar.start(10)
        threading.Thread(target=self._install_thread,
                         args=(dest,), daemon=True).start()

    def _install_thread(self, dest: Path):
        def ui(fn): self.after(0, fn)

        try:
            dest.mkdir(parents=True, exist_ok=True)
            game_dir = dest / "game"

            # Step 0 — Clone ──────────────────────────────────────────────────
            ui(lambda: self._step_start(0, "Cloning repository — this may take 10–20 minutes…"))
            if game_dir.exists():
                shutil.rmtree(game_dir)
            subprocess.run(
                ["git", "clone", "--branch", REPO_BRANCH,
                 "--progress", REPO_URL, str(game_dir)],
                check=True)
            subprocess.run(["git", "lfs", "pull"], cwd=game_dir, check=True)
            ui(lambda: self._step_done(0))

            # Step 1 — Download Godot ─────────────────────────────────────────
            ui(lambda: self._step_start(1, f"Downloading Godot {GODOT_VER}…"))
            godot_dir = dest / "godot"
            godot_dir.mkdir(exist_ok=True)
            godot_zip = godot_dir / "godot.zip"
            url = GODOT_URL_WIN if IS_WIN else (GODOT_URL_MAC if IS_MAC else GODOT_URL_LIN)
            self._download(url, godot_zip)
            ui(lambda: self._step_done(1))

            # Step 2 — Extract ────────────────────────────────────────────────
            ui(lambda: self._step_start(2, "Extracting Godot…"))
            with zipfile.ZipFile(godot_zip, "r") as z:
                z.extractall(godot_dir)
            godot_zip.unlink(missing_ok=True)
            godot_exe = self._find_godot_binary(godot_dir)
            ui(lambda: self._step_done(2))

            # Step 3 — Launcher ───────────────────────────────────────────────
            ui(lambda: self._step_start(3, "Creating launcher and desktop shortcut…"))
            if IS_WIN:
                launcher = dest / "Play Hunt Down Joe Biden.bat"
                launcher.write_text(
                    f'@echo off\nstart "" "{godot_exe}" --path "{game_dir}"\n',
                    encoding="utf-8")
                self._create_shortcut(
                    name=GAME_TITLE,
                    target=str(launcher),
                    icon=str(game_dir / "icon.svg"),
                    work_dir=str(dest))
            else:
                launcher = dest / "play.sh"
                launcher.write_text(
                    f'#!/bin/sh\n"{godot_exe}" --path "{game_dir}"\n',
                    encoding="utf-8")
                launcher.chmod(0o755)
            ui(lambda: self._step_done(3))

            # Done ─────────────────────────────────────────────────────────────
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

    # ── Step UI helpers (MUST be called on main thread via after()) ────────────
    def _step_start(self, idx: int, status: str):
        self._step_icons[idx].configure(text="▶", fg=ORANGE)
        self._step_labels[idx].configure(fg=WHITE)
        self._status_var.set(status)

    def _step_done(self, idx: int):
        self._step_icons[idx].configure(text="✓", fg=GREEN)
        self._step_labels[idx].configure(fg=GREEN)

    # ── Helpers ────────────────────────────────────────────────────────────────
    def _download(self, url: str, dest: Path):
        tmp = str(dest) + ".part"
        def _progress(count, block, total):
            if total > 0:
                pct = min(int(count * block * 100 / total), 100)
                mb  = count * block / 1_048_576
                msg = f"Downloading Godot {GODOT_VER}…  {mb:.1f} MB  ({pct}%)"
                self.after(0, lambda m=msg: self._status_var.set(m))
        urllib.request.urlretrieve(url, tmp, reporthook=_progress)
        os.replace(tmp, dest)

    def _find_godot_binary(self, godot_dir: Path) -> Path:
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
            ps = (
                f'$ws = New-Object -ComObject WScript.Shell; '
                f'$s = $ws.CreateShortcut("{desktop / (name + ".lnk")}"); '
                f'$s.TargetPath = "{target}"; '
                f'$s.WorkingDirectory = "{work_dir}"; '
                f'$s.Save()'
            )
            subprocess.run(["powershell", "-NoProfile", "-Command", ps],
                           capture_output=True)
        except Exception:
            pass

    def _launch(self, launcher: Path):
        try:
            if IS_WIN:
                os.startfile(str(launcher))
            else:
                subprocess.Popen([str(launcher)])
        except Exception:
            pass
        self.destroy()

    def _fail(self, msg: str):
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
    def _default_dir() -> str:
        if IS_WIN:   return DEFAULT_DIR_WIN
        if IS_MAC:   return DEFAULT_DIR_MAC
        return DEFAULT_DIR_LIN

    @staticmethod
    def _open_url(url: str):
        import webbrowser
        webbrowser.open(url)

    def _center(self, w: int, h: int):
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
