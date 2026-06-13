"""
Hunt Down Joe Biden - Installer v1.0
"""

import sys, os, shutil, subprocess, threading, platform, urllib.request
import zipfile, ctypes
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

# Safe cross-platform fonts — no Segoe UI dependency
F_TITLE = ("Arial", 20, "bold")
F_BODY  = ("Arial", 10)
F_MONO  = ("Courier", 10)
F_SMALL = ("Arial", 9)
F_BTN   = ("Arial", 11, "bold")


class Installer(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Hunt Down Joe Biden - Installer")
        self.resizable(False, False)
        self.configure(bg=BG)
        self._center(780, 560)

        self._dir     = tk.StringVar(value=DEFAULT_DIR)
        self._busy    = False
        self._git_ok  = False
        self._lfs_ok  = False

        self._build_ui()
        # Prereq check deferred so window paints first
        self.after(100, self._check_prereqs)

    # ------------------------------------------------------------------
    def _build_ui(self):
        # Orange strip at top
        tk.Frame(self, bg=ORANGE, height=5).pack(side="top", fill="x")

        # === BOTTOM BAR (packed first = always visible) ================
        bot = tk.Frame(self, bg=BG2, pady=12, padx=20)
        bot.pack(side="bottom", fill="x")

        self._btn = tk.Button(
            bot, text="Install & Play",
            font=F_BTN, bg=ORANGE, fg="#000",
            activebackground="#ffb84d", activeforeground="#000",
            relief="flat", bd=0, padx=22, pady=8,
            cursor="hand2", command=self._start)
        self._btn.pack(side="right")

        tk.Button(bot, text="Cancel", font=F_SMALL,
                  bg=BG2, fg=GREY, activebackground=BG3,
                  relief="flat", bd=0, padx=10, pady=8,
                  cursor="hand2", command=self.destroy
                  ).pack(side="right", padx=(0, 6))

        self._status = tk.StringVar(value="Checking requirements...")
        tk.Label(bot, textvariable=self._status,
                 font=F_SMALL, fg=GREY, bg=BG2, anchor="w"
                 ).pack(side="left", fill="x", expand=True)

        # Progress bar just above bottom bar
        pf = tk.Frame(self, bg=BG)
        pf.pack(side="bottom", fill="x")
        self._bar = ttk.Progressbar(pf, mode="indeterminate")
        self._bar.pack(fill="x")
        sty = ttk.Style(self)
        sty.theme_use("default")
        sty.configure("TProgressbar", troughcolor=BG2,
                      background=ORANGE, thickness=6)

        # === SCROLLABLE CONTENT =======================================
        wrap = tk.Frame(self, bg=BG)
        wrap.pack(side="top", fill="both", expand=True)

        cv = tk.Canvas(wrap, bg=BG, highlightthickness=0, bd=0)
        sb = tk.Scrollbar(wrap, orient="vertical", command=cv.yview,
                          bg=BG2, troughcolor=BG2)
        cv.configure(yscrollcommand=sb.set)
        sb.pack(side="right", fill="y")
        cv.pack(side="left", fill="both", expand=True)

        inner = tk.Frame(cv, bg=BG)
        win_id = cv.create_window((0, 0), window=inner, anchor="nw")

        inner.bind("<Configure>",
                   lambda e: cv.configure(scrollregion=cv.bbox("all")))
        cv.bind("<Configure>",
                lambda e: cv.itemconfig(win_id, width=e.width))

        def _scroll(e):
            delta = -1 if e.delta > 0 else 1
            cv.yview_scroll(delta, "units")
        cv.bind_all("<MouseWheel>", _scroll)

        self._fill_content(inner)

    def _fill_content(self, p):
        PAD = dict(padx=28)

        # Title
        h = tk.Frame(p, bg=BG)
        h.pack(fill="x", pady=(18, 12), **PAD)
        tk.Label(h, text=GAME_TITLE, font=F_TITLE,
                 fg=ORANGE, bg=BG, anchor="w").pack(fill="x")
        tk.Label(h, text="A Half-Life 2 parody FPS  |  Installer v1.0",
                 font=F_SMALL, fg=GREY, bg=BG, anchor="w").pack(fill="x")

        tk.Frame(p, bg=GREY2, height=1).pack(fill="x", **PAD, pady=(0, 8))

        # --- Requirements --------------------------------------------
        self._head(p, "REQUIREMENTS")
        rf = tk.Frame(p, bg=BG2, padx=14, pady=10)
        rf.pack(fill="x", pady=(4, 10), **PAD)

        self._git_lbl = tk.Label(rf, text="Git:      Checking...",
                                 font=F_MONO, fg=GREY, bg=BG2, anchor="w")
        self._git_lbl.pack(fill="x")
        gl = tk.Label(rf, text="  -> Download Git (git-scm.com)",
                      font=F_SMALL, fg=BLUE, bg=BG2, anchor="w", cursor="hand2")
        gl.pack(fill="x")
        gl.bind("<Button-1>", lambda *_: self._open(GIT_INSTALL_URL))

        self._lfs_lbl = tk.Label(rf, text="Git LFS:  Checking...",
                                 font=F_MONO, fg=GREY, bg=BG2, anchor="w")
        self._lfs_lbl.pack(fill="x", pady=(6, 0))
        ll = tk.Label(rf, text="  -> Download Git LFS (git-lfs.github.com)",
                      font=F_SMALL, fg=BLUE, bg=BG2, anchor="w", cursor="hand2")
        ll.pack(fill="x")
        ll.bind("<Button-1>", lambda *_: self._open(LFS_INSTALL_URL))

        # --- Install location ----------------------------------------
        self._head(p, "INSTALL LOCATION")
        lf = tk.Frame(p, bg=BG2, padx=14, pady=10)
        lf.pack(fill="x", pady=(4, 10), **PAD)

        row = tk.Frame(lf, bg=BG2)
        row.pack(fill="x")
        tk.Entry(row, textvariable=self._dir, font=F_MONO,
                 bg=BG3, fg=WHITE, insertbackground=WHITE,
                 relief="flat", bd=2).pack(
            side="left", fill="x", expand=True, ipady=4)
        tk.Button(row, text="Browse", font=F_SMALL,
                  bg=BG3, fg=WHITE, activebackground=ORANGE,
                  relief="flat", bd=0, padx=8, pady=4,
                  cursor="hand2", command=self._browse
                  ).pack(side="right", padx=(6, 0))
        tk.Label(lf, text="Approx. 3 GB will be downloaded.",
                 font=F_SMALL, fg=GREY, bg=BG2, anchor="w").pack(
            fill="x", pady=(5, 0))

        # --- Steps ---------------------------------------------------
        self._head(p, "INSTALL STEPS")
        sf = tk.Frame(p, bg=BG2, padx=14, pady=10)
        sf.pack(fill="x", pady=(4, 16), **PAD)

        steps = [
            "Clone game repository (~3 GB)",
            f"Download Godot {GODOT_VER}",
            "Extract Godot",
            "Create launcher + desktop shortcut",
        ]
        self._slbls = []
        for txt in steps:
            lbl = tk.Label(sf, text=f"[ ] {txt}",
                           font=F_BODY, fg=GREY2, bg=BG2, anchor="w")
            lbl.pack(fill="x", pady=1)
            self._slbls.append(lbl)

    def _head(self, p, text):
        tk.Label(p, text=text, font=("Arial", 8, "bold"),
                 fg=GREY, bg=BG, anchor="w").pack(fill="x", padx=28)

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

        g_txt = "[OK] Git:      Found" if git_ok else "[!!] Git:      NOT FOUND"
        l_txt = "[OK] Git LFS:  Found" if lfs_ok else "[!!] Git LFS:  NOT FOUND"
        self._git_lbl.configure(text=g_txt, fg=(GREEN if git_ok else RED))
        self._lfs_lbl.configure(text=l_txt, fg=(GREEN if lfs_ok else RED))

        if git_ok and lfs_ok:
            self._status.set("Ready to install.")
        else:
            missing = ", ".join(
                (["Git"] if not git_ok else []) + (["Git LFS"] if not lfs_ok else []))
            self._status.set(f"Install {missing} first, then re-run.")
            self._btn.configure(
                bg=GREY2, fg=GREY,
                text=f"Missing: {missing}",
                command=lambda: messagebox.showinfo(
                    "Prerequisites required",
                    "Please install the items marked [!!] above,\n"
                    "then close and re-run this installer.\n\n"
                    f"Git:     {GIT_INSTALL_URL}\n"
                    f"Git LFS: {LFS_INSTALL_URL}"))

    # ------------------------------------------------------------------
    def _start(self):
        if self._busy:
            return
        if not (self._git_ok and self._lfs_ok):
            messagebox.showwarning("Not ready",
                                   "Please install Git and Git LFS first.")
            return
        self._busy = True
        dest = Path(self._dir.get()).resolve()
        self._btn.configure(state="disabled", bg=GREY2, fg=GREY,
                            text="Installing...")
        self._bar.start(10)
        threading.Thread(target=self._run, args=(dest,), daemon=True).start()

    def _run(self, dest):
        def ui(f): self.after(0, f)

        def step(i, active):
            names = [
                "Clone game repository (~3 GB)",
                f"Download Godot {GODOT_VER}",
                "Extract Godot",
                "Create launcher + desktop shortcut",
            ]
            marker = ">>>" if active else "[X]"
            color  = ORANGE if active else GREEN
            self._slbls[i].configure(
                text=f"{marker} {names[i]}", fg=color)

        try:
            dest.mkdir(parents=True, exist_ok=True)
            game_dir = dest / "game"

            ui(lambda: step(0, True))
            ui(lambda: self._status.set("Cloning repo — may take 10-20 min..."))
            if game_dir.exists():
                shutil.rmtree(game_dir)
            subprocess.run(["git", "clone", "--branch", REPO_BRANCH,
                            REPO_URL, str(game_dir)], check=True)
            subprocess.run(["git", "lfs", "pull"],
                           cwd=game_dir, check=True)
            ui(lambda: step(0, False))

            ui(lambda: step(1, True))
            godot_dir = dest / "godot"
            godot_dir.mkdir(exist_ok=True)
            godot_zip = godot_dir / "godot.zip"
            url = GODOT_URL_WIN if IS_WIN else (
                  GODOT_URL_MAC if IS_MAC else GODOT_URL_LIN)
            self._dl(url, godot_zip)
            ui(lambda: step(1, False))

            ui(lambda: step(2, True))
            ui(lambda: self._status.set("Extracting Godot..."))
            with zipfile.ZipFile(godot_zip, "r") as z:
                z.extractall(godot_dir)
            godot_zip.unlink(missing_ok=True)
            godot_exe = self._find_godot(godot_dir)
            ui(lambda: step(2, False))

            ui(lambda: step(3, True))
            ui(lambda: self._status.set("Creating launcher..."))
            if IS_WIN:
                launcher = dest / "Play Hunt Down Joe Biden.bat"
                launcher.write_text(
                    f'@echo off\nstart "" "{godot_exe}" --path "{game_dir}"\n',
                    encoding="utf-8")
                self._shortcut(GAME_TITLE, str(launcher), str(dest))
            else:
                launcher = dest / "play.sh"
                launcher.write_text(
                    f'#!/bin/sh\n"{godot_exe}" --path "{game_dir}"\n',
                    encoding="utf-8")
                launcher.chmod(0o755)
            ui(lambda: step(3, False))

            def finish():
                self._bar.stop()
                self._bar.configure(mode="determinate")
                self._bar["value"] = 100
                self._status.set("Done! Installation complete.")
                self._btn.configure(state="normal", bg=GREEN, fg="#000",
                                    text="Play Now!",
                                    command=lambda: self._launch(launcher))
            ui(finish)

        except subprocess.CalledProcessError as e:
            ui(lambda: self._fail(f"Command failed:\n{e}"))
        except Exception as e:
            msg = str(e)
            ui(lambda: self._fail(msg))

    # ------------------------------------------------------------------
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
            if IS_WIN: os.startfile(str(launcher))
            else:      subprocess.Popen([str(launcher)])
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
        # Last-resort: if tkinter itself fails, at least show something
        try:
            import tkinter as tk
            r = tk.Tk()
            r.title("Installer Error")
            tk.Label(r, text=f"Startup error:\n{e}", padx=20, pady=20).pack()
            tk.Button(r, text="Close", command=r.destroy).pack(pady=10)
            r.mainloop()
        except Exception:
            pass
