"""
Hunt Down Joe Biden - Installer v1.0
"""

import sys, os, shutil, subprocess, threading, platform, urllib.request
import zipfile
from pathlib import Path

import tkinter as tk
from tkinter import ttk, messagebox, filedialog

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

IS_WIN = platform.system() == "Windows"
IS_MAC = platform.system() == "Darwin"
DEFAULT_DIR = str(Path.home() / ("Games" if not IS_MAC else "Applications") / "HuntDownJoeBiden")

BG     = "#111111"
BG2    = "#1e1e1e"
BG3    = "#2a2a2a"
ORANGE = "#ff9e1b"
WHITE  = "#e8e8e8"
GREY   = "#888888"
GREY2  = "#444444"
RED    = "#dd4444"
GREEN  = "#44bb44"
BLUE   = "#5588cc"


class Installer(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Hunt Down Joe Biden - Installer")
        self.resizable(False, False)
        self.configure(bg=BG)
        self._center(700, 480)

        self._dir    = tk.StringVar(value=DEFAULT_DIR)
        self._busy   = False
        self._git_ok = False
        self._lfs_ok = False

        self._build_ui()
        self.after(100, self._check_prereqs)

    def _build_ui(self):
        # Orange top strip
        tk.Frame(self, bg=ORANGE, height=5).pack(fill="x")

        # Header
        tk.Label(self, text=GAME_TITLE, font=("Arial", 18, "bold"),
                 fg=ORANGE, bg=BG).pack(anchor="w", padx=20, pady=(12, 0))
        tk.Label(self, text="Half-Life 2 parody FPS  |  Installer v1.0",
                 font=("Arial", 9), fg=GREY, bg=BG).pack(anchor="w", padx=20)

        tk.Frame(self, bg=GREY2, height=1).pack(fill="x", padx=20, pady=8)

        # Requirements
        tk.Label(self, text="REQUIREMENTS", font=("Arial", 8, "bold"),
                 fg=GREY, bg=BG).pack(anchor="w", padx=20)

        rf = tk.Frame(self, bg=BG2)
        rf.pack(fill="x", padx=20, pady=(3, 8))

        self._git_lbl = tk.Label(rf, text="  Git:     checking...",
                                 font=("Courier", 10), fg=GREY, bg=BG2, anchor="w")
        self._git_lbl.pack(fill="x", pady=(6, 0))
        self._lfs_lbl = tk.Label(rf, text="  Git LFS: checking...",
                                 font=("Courier", 10), fg=GREY, bg=BG2, anchor="w")
        self._lfs_lbl.pack(fill="x", pady=(2, 0))

        link_row = tk.Frame(rf, bg=BG2)
        link_row.pack(fill="x", pady=(4, 6))
        self._make_link(link_row, "Download Git", GIT_INSTALL_URL).pack(side="left", padx=(6, 0))
        tk.Label(link_row, text="  |  ", fg=GREY2, bg=BG2,
                 font=("Arial", 9)).pack(side="left")
        self._make_link(link_row, "Download Git LFS", LFS_INSTALL_URL).pack(side="left")

        tk.Frame(self, bg=GREY2, height=1).pack(fill="x", padx=20, pady=(0, 8))

        # Install location
        tk.Label(self, text="INSTALL LOCATION", font=("Arial", 8, "bold"),
                 fg=GREY, bg=BG).pack(anchor="w", padx=20)

        lf = tk.Frame(self, bg=BG2)
        lf.pack(fill="x", padx=20, pady=(3, 8))

        er = tk.Frame(lf, bg=BG2)
        er.pack(fill="x", padx=6, pady=6)
        tk.Entry(er, textvariable=self._dir, font=("Courier", 10),
                 bg=BG3, fg=WHITE, insertbackground=WHITE,
                 relief="flat", bd=2).pack(side="left", fill="x", expand=True, ipady=4)
        tk.Button(er, text="Browse", font=("Arial", 9),
                  bg=BG3, fg=WHITE, activebackground=ORANGE, relief="flat",
                  bd=0, padx=8, pady=4, cursor="hand2",
                  command=self._browse).pack(side="right", padx=(6, 0))
        tk.Label(lf, text="  ~3 GB will be downloaded",
                 font=("Arial", 8), fg=GREY, bg=BG2, anchor="w").pack(fill="x", pady=(0, 4))

        tk.Frame(self, bg=GREY2, height=1).pack(fill="x", padx=20, pady=(0, 8))

        # Steps
        tk.Label(self, text="STEPS", font=("Arial", 8, "bold"),
                 fg=GREY, bg=BG).pack(anchor="w", padx=20)

        sf = tk.Frame(self, bg=BG2)
        sf.pack(fill="x", padx=20, pady=(3, 8))

        step_names = [
            "Clone game repository (~3 GB)",
            f"Download Godot {GODOT_VER}",
            "Extract Godot",
            "Create launcher + desktop shortcut",
        ]
        self._slbls = []
        for name in step_names:
            lbl = tk.Label(sf, text=f"  [ ] {name}",
                           font=("Arial", 9), fg=GREY2, bg=BG2, anchor="w")
            lbl.pack(fill="x", pady=1)
            self._slbls.append(lbl)

        # Status + progress bar
        self._status = tk.StringVar(value="Checking requirements...")
        tk.Label(self, textvariable=self._status,
                 font=("Arial", 9), fg=GREY, bg=BG, anchor="w").pack(
            fill="x", padx=20, pady=(4, 2))

        self._bar = ttk.Progressbar(self, mode="indeterminate")
        self._bar.pack(fill="x", padx=20)
        sty = ttk.Style(self)
        sty.theme_use("default")
        sty.configure("TProgressbar", troughcolor=BG2,
                      background=ORANGE, thickness=6)

        # Buttons — pack last so they're at the bottom
        bf = tk.Frame(self, bg=BG2)
        bf.pack(fill="x", pady=12, padx=20, side="bottom")

        self._btn = tk.Button(
            bf, text="Install & Play",
            font=("Arial", 11, "bold"), bg=ORANGE, fg="#000",
            activebackground="#ffb84d", activeforeground="#000",
            relief="flat", bd=0, padx=20, pady=8,
            cursor="hand2", command=self._start)
        self._btn.pack(side="right")

        tk.Button(bf, text="Cancel", font=("Arial", 9),
                  bg=BG2, fg=GREY, activebackground=BG3,
                  relief="flat", bd=0, padx=10, pady=8,
                  cursor="hand2", command=self.destroy
                  ).pack(side="right", padx=(0, 8))

    def _make_link(self, parent, text, url):
        lbl = tk.Label(parent, text=text, font=("Arial", 9),
                       fg=BLUE, bg=BG2, cursor="hand2")
        lbl.bind("<Button-1>", lambda *_: self._open(url))
        return lbl

    # ------------------------------------------------------------------
    def _check_prereqs(self):
        def _run():
            git_ok = shutil.which("git") is not None
            lfs_ok = False
            if git_ok:
                try:
                    r = subprocess.run(["git", "lfs", "version"],
                                       capture_output=True, timeout=6)
                    lfs_ok = r.returncode == 0
                except Exception:
                    pass
            self.after(0, lambda: self._show_prereqs(git_ok, lfs_ok))
        threading.Thread(target=_run, daemon=True).start()

    def _show_prereqs(self, git_ok, lfs_ok):
        self._git_ok = git_ok
        self._lfs_ok = lfs_ok
        self._git_lbl.configure(
            text=f"  Git:     {'[OK] Found' if git_ok else '[!!] NOT FOUND'}",
            fg=(GREEN if git_ok else RED))
        self._lfs_lbl.configure(
            text=f"  Git LFS: {'[OK] Found' if lfs_ok else '[!!] NOT FOUND'}",
            fg=(GREEN if lfs_ok else RED))
        if git_ok and lfs_ok:
            self._status.set("Ready to install.")
        else:
            missing = ", ".join((["Git"] if not git_ok else []) +
                                (["Git LFS"] if not lfs_ok else []))
            self._status.set(f"Please install {missing} (links above), then re-run.")
            self._btn.configure(bg=GREY2, fg=GREY, text=f"Missing: {missing}",
                                command=lambda: messagebox.showinfo(
                                    "Prerequisites",
                                    f"Install {missing} using the links above,\n"
                                    "then close and re-run this installer."))

    # ------------------------------------------------------------------
    def _start(self):
        if self._busy:
            return
        if not (self._git_ok and self._lfs_ok):
            messagebox.showwarning("Not ready", "Install Git and Git LFS first.")
            return
        self._busy = True
        dest = Path(self._dir.get()).resolve()
        self._btn.configure(state="disabled", bg=GREY2, fg=GREY, text="Installing...")
        self._bar.start(10)
        threading.Thread(target=self._run, args=(dest,), daemon=True).start()

    def _run(self, dest):
        def ui(f): self.after(0, f)
        def step_active(i, name):
            self._slbls[i].configure(text=f"  >>> {name}", fg=ORANGE)
        def step_done(i, name):
            self._slbls[i].configure(text=f"  [X] {name}", fg=GREEN)

        names = [
            "Clone game repository (~3 GB)",
            f"Download Godot {GODOT_VER}",
            "Extract Godot",
            "Create launcher + desktop shortcut",
        ]

        try:
            dest.mkdir(parents=True, exist_ok=True)
            game_dir = dest / "game"

            ui(lambda: step_active(0, names[0]))
            ui(lambda: self._status.set("Cloning repo - may take 10-20 min..."))
            if game_dir.exists():
                shutil.rmtree(game_dir)
            subprocess.run(["git", "clone", "--branch", REPO_BRANCH,
                            REPO_URL, str(game_dir)], check=True)
            subprocess.run(["git", "lfs", "pull"], cwd=game_dir, check=True)
            ui(lambda: step_done(0, names[0]))

            ui(lambda: step_active(1, names[1]))
            godot_dir = dest / "godot"
            godot_dir.mkdir(exist_ok=True)
            godot_zip = godot_dir / "godot.zip"
            url = GODOT_URL_WIN if IS_WIN else (GODOT_URL_MAC if IS_MAC else GODOT_URL_LIN)
            self._dl(url, godot_zip)
            ui(lambda: step_done(1, names[1]))

            ui(lambda: step_active(2, names[2]))
            ui(lambda: self._status.set("Extracting Godot..."))
            with zipfile.ZipFile(godot_zip, "r") as z:
                z.extractall(godot_dir)
            godot_zip.unlink(missing_ok=True)
            godot_exe = self._find_godot(godot_dir)
            ui(lambda: step_done(2, names[2]))

            ui(lambda: step_active(3, names[3]))
            if IS_WIN:
                launcher = dest / "Play Hunt Down Joe Biden.bat"
                launcher.write_text(
                    f'@echo off\nstart "" "{godot_exe}" --path "{game_dir}"\n',
                    encoding="utf-8")
                self._shortcut(GAME_TITLE, str(launcher), str(dest))
            else:
                launcher = dest / "play.sh"
                launcher.write_text(f'#!/bin/sh\n"{godot_exe}" --path "{game_dir}"\n',
                                    encoding="utf-8")
                launcher.chmod(0o755)
            ui(lambda: step_done(3, names[3]))

            def finish():
                self._bar.stop()
                self._bar.configure(mode="determinate")
                self._bar["value"] = 100
                self._status.set("Installation complete!")
                self._btn.configure(state="normal", bg=GREEN, fg="#000",
                                    text="Play Now!",
                                    command=lambda: self._launch(launcher))
            ui(finish)

        except subprocess.CalledProcessError as e:
            ui(lambda: self._fail(f"Command failed:\n{e}"))
        except Exception as e:
            msg = str(e)
            ui(lambda: self._fail(msg))

    def _dl(self, url, dest):
        tmp = str(dest) + ".part"
        def progress(count, block, total):
            if total > 0:
                pct = min(int(count * block * 100 / total), 100)
                mb  = count * block / 1_048_576
                msg = f"Downloading Godot... {mb:.1f} MB ({pct}%)"
                self.after(0, lambda m=msg: self._status.set(m))
        urllib.request.urlretrieve(url, tmp, reporthook=progress)
        os.replace(tmp, dest)

    def _find_godot(self, d):
        exts = [".exe"] if IS_WIN else ([""] if not IS_MAC else [".app/Contents/MacOS/Godot"])
        for f in d.rglob("*"):
            n = f.name.lower()
            if "godot" in n and any(n.endswith(e) for e in exts):
                return f
        for f in d.iterdir():
            if f.is_file() and os.access(f, os.X_OK):
                return f
        raise FileNotFoundError("Godot binary not found after extraction.")

    def _shortcut(self, name, target, work_dir):
        try:
            desktop = Path.home() / "Desktop"
            if not desktop.exists():
                return
            ps = (f'$ws=New-Object -ComObject WScript.Shell;'
                  f'$s=$ws.CreateShortcut("{desktop / (name + ".lnk")}");'
                  f'$s.TargetPath="{target}";'
                  f'$s.WorkingDirectory="{work_dir}";$s.Save()')
            subprocess.run(["powershell", "-NoProfile", "-Command", ps],
                           capture_output=True)
        except Exception:
            pass

    def _launch(self, launcher):
        try:
            if IS_WIN:
                os.startfile(str(launcher))
            else:
                subprocess.Popen([str(launcher)])
        except Exception:
            pass
        self.destroy()

    def _fail(self, msg):
        self._bar.stop()
        self._busy = False
        self._status.set("Installation failed.")
        self._btn.configure(state="normal", bg=RED, fg=WHITE,
                            text="Retry", command=self._start)
        messagebox.showerror("Installation failed", msg)

    def _browse(self):
        d = filedialog.askdirectory(title="Choose install location")
        if d:
            self._dir.set(d)

    @staticmethod
    def _open(url):
        import webbrowser
        webbrowser.open(url)

    def _center(self, w, h):
        self.update_idletasks()
        sw = self.winfo_screenwidth()
        sh = self.winfo_screenheight()
        self.geometry(f"{w}x{h}+{(sw-w)//2}+{(sh-h)//2}")


if __name__ == "__main__":
    try:
        app = Installer()
        app.mainloop()
    except Exception as e:
        try:
            r = tk.Tk()
            r.title("Installer Error")
            tk.Label(r, text=f"Error:\n\n{e}", padx=20, pady=20,
                     font=("Arial", 10), justify="left").pack()
            tk.Button(r, text="Close", command=r.destroy,
                      padx=10, pady=6).pack(pady=10)
            r.mainloop()
        except Exception:
            pass
