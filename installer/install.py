"""
Hunt Down Joe Biden — Installer v1.0
Checks prerequisites, clones the game repo (with all LFS assets),
downloads Godot 4.4, creates a launcher and desktop shortcut.
"""

import sys, os, shutil, subprocess, threading, platform, urllib.request
import zipfile, tempfile, time, ctypes
from pathlib import Path

# ── tkinter (bundled with Python / PyInstaller) ───────────────────────────────
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
BG       = "#1a1a1a"
BG2      = "#2a2a2a"
ORANGE   = "#ff9e1b"
WHITE    = "#e8e8e8"
GREY     = "#777777"
RED      = "#cc3333"
GREEN    = "#44bb44"

# ═══════════════════════════════════════════════════════════════════════════════
class Installer(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title(f"{GAME_TITLE} — Installer")
        self.resizable(False, False)
        self.configure(bg=BG)
        self._center(700, 480)
        self._install_dir = tk.StringVar(value=self._default_dir())
        self._build_ui()
        self._check_prereqs()

    # ── Layout ─────────────────────────────────────────────────────────────────
    def _build_ui(self):
        # Header
        hdr = tk.Frame(self, bg=BG, padx=28, pady=18)
        hdr.pack(fill="x")
        tk.Label(hdr, text=GAME_TITLE, font=("Arial", 22, "bold"),
                 fg=ORANGE, bg=BG).pack(anchor="w")
        tk.Label(hdr, text="A Half-Life 2 parody FPS  •  Installer v1.0",
                 font=("Arial", 10), fg=GREY, bg=BG).pack(anchor="w")

        sep = tk.Frame(self, bg=ORANGE, height=2)
        sep.pack(fill="x")

        # Prereq panel
        pf = tk.LabelFrame(self, text=" Requirements ", font=("Arial", 9, "bold"),
                            fg=WHITE, bg=BG2, bd=1, relief="solid",
                            padx=14, pady=10)
        pf.pack(fill="x", padx=24, pady=(14, 6))

        self._git_var  = tk.StringVar(value="Checking…")
        self._lfs_var  = tk.StringVar(value="Checking…")
        self._git_col  = tk.StringVar(value=GREY)
        self._lfs_col  = tk.StringVar(value=GREY)

        self._req_row(pf, "Git",         self._git_var, self._git_col,
                      GIT_INSTALL_URL, 0)
        self._req_row(pf, "Git LFS",     self._lfs_var, self._lfs_col,
                      LFS_INSTALL_URL, 1)

        # Install dir
        df = tk.LabelFrame(self, text=" Install location ", font=("Arial", 9, "bold"),
                            fg=WHITE, bg=BG2, bd=1, relief="solid",
                            padx=14, pady=10)
        df.pack(fill="x", padx=24, pady=6)

        row = tk.Frame(df, bg=BG2)
        row.pack(fill="x")
        tk.Entry(row, textvariable=self._install_dir, font=("Consolas", 10),
                 bg="#111", fg=WHITE, insertbackground=WHITE,
                 relief="flat", bd=4).pack(side="left", fill="x", expand=True)
        tk.Button(row, text="Browse…", font=("Arial", 9),
                  bg=BG, fg=WHITE, activebackground=ORANGE,
                  relief="flat", bd=0, padx=8,
                  command=self._browse).pack(side="right", padx=(6, 0))

        # Progress
        pg = tk.Frame(self, bg=BG, padx=24, pady=6)
        pg.pack(fill="x")
        self._status = tk.StringVar(value="Ready.")
        tk.Label(pg, textvariable=self._status, font=("Arial", 9),
                 fg=WHITE, bg=BG, anchor="w").pack(fill="x")
        self._bar = ttk.Progressbar(pg, mode="indeterminate", length=652)
        self._bar.pack(fill="x", pady=(4, 0))
        style = ttk.Style(self)
        style.theme_use("default")
        style.configure("TProgressbar", troughcolor=BG2,
                        background=ORANGE, thickness=10)

        # Buttons
        bf = tk.Frame(self, bg=BG, padx=24, pady=14)
        bf.pack(fill="x", side="bottom")
        tk.Label(bf, text="~3 GB will be downloaded (game assets via Git LFS)",
                 font=("Arial", 8), fg=GREY, bg=BG).pack(side="left")
        self._install_btn = tk.Button(bf, text="Install & Play",
                                      font=("Arial", 11, "bold"),
                                      bg=ORANGE, fg="#000",
                                      activebackground="#ffb84d",
                                      relief="flat", bd=0, padx=18, pady=8,
                                      command=self._start_install)
        self._install_btn.pack(side="right")

    def _req_row(self, parent, label, var, col_var, url, row):
        f = tk.Frame(parent, bg=BG2)
        f.grid(row=row, column=0, sticky="w", pady=2)
        tk.Label(f, text=f"  {label:<12}", font=("Consolas", 10),
                 fg=WHITE, bg=BG2).pack(side="left")
        lbl = tk.Label(f, textvariable=var, font=("Consolas", 10, "bold"),
                       bg=BG2)
        lbl.pack(side="left")
        # update colour dynamically
        def _update(*_):
            lbl.configure(fg=col_var.get())
        col_var.trace_add("write", _update)
        tk.Label(f, text=f"  →  ", fg=GREY, bg=BG2,
                 font=("Arial", 9)).pack(side="left")
        link = tk.Label(f, text="Download", font=("Arial", 9, "underline"),
                        fg="#6699cc", bg=BG2, cursor="hand2")
        link.pack(side="left")
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

            self._git_var.set("✓  Found" if git_ok else "✗  Not found")
            self._git_col.set(GREEN if git_ok else RED)
            self._lfs_var.set("✓  Found" if lfs_ok else "✗  Not found")
            self._lfs_col.set(GREEN if lfs_ok else RED)

            if not git_ok or not lfs_ok:
                self._install_btn.configure(
                    text="Install prerequisites first",
                    bg="#444", fg=GREY)
                self._install_btn.configure(command=lambda: messagebox.showinfo(
                    "Prerequisites required",
                    "Please install Git and Git LFS, then re-run the installer.\n\n"
                    "Git:     https://git-scm.com/download/win\n"
                    "Git LFS: https://git-lfs.github.com/"))
            else:
                self._install_btn.configure(
                    text="Install & Play",
                    bg=ORANGE, fg="#000",
                    command=self._start_install)
        threading.Thread(target=_run, daemon=True).start()

    # ── Install flow ───────────────────────────────────────────────────────────
    def _start_install(self):
        dest = Path(self._install_dir.get()).resolve()
        self._install_btn.configure(state="disabled")
        self._bar.start(12)
        threading.Thread(target=self._install_thread,
                         args=(dest,), daemon=True).start()

    def _install_thread(self, dest: Path):
        try:
            dest.mkdir(parents=True, exist_ok=True)
            game_dir = dest / "game"

            # 1. Clone repo --------------------------------------------------
            self._set_status("Cloning repository (this downloads ~3 GB of game assets)…")
            if game_dir.exists():
                shutil.rmtree(game_dir)
            subprocess.run(
                ["git", "clone", "--branch", REPO_BRANCH,
                 "--progress", REPO_URL, str(game_dir)],
                check=True)
            # Ensure LFS objects are fetched
            subprocess.run(["git", "lfs", "pull"],
                           cwd=game_dir, check=True)

            # 2. Download Godot ----------------------------------------------
            self._set_status(f"Downloading Godot {GODOT_VER}…")
            godot_dir = dest / "godot"
            godot_dir.mkdir(exist_ok=True)
            godot_zip = godot_dir / "godot.zip"

            url = GODOT_URL_WIN if IS_WIN else (
                  GODOT_URL_MAC if IS_MAC else GODOT_URL_LIN)
            self._download(url, godot_zip)

            # 3. Extract Godot -----------------------------------------------
            self._set_status("Extracting Godot…")
            with zipfile.ZipFile(godot_zip, "r") as z:
                z.extractall(godot_dir)
            godot_zip.unlink(missing_ok=True)

            # Find the extracted exe / binary
            godot_exe = self._find_godot_binary(godot_dir)

            # 4. Write launcher ----------------------------------------------
            self._set_status("Creating launcher…")
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

            # 5. Done --------------------------------------------------------
            self._bar.stop()
            self._set_status("Installation complete!")
            ans = messagebox.askyesno(
                "Done!", f"{GAME_TITLE} is installed.\nPlay now?")
            if ans:
                if IS_WIN:
                    os.startfile(str(launcher))
                else:
                    subprocess.Popen([str(launcher)])
            self.destroy()

        except subprocess.CalledProcessError as e:
            self._fail(f"Command failed:\n{e}")
        except Exception as e:
            self._fail(str(e))

    # ── Helpers ────────────────────────────────────────────────────────────────
    def _download(self, url: str, dest: Path):
        tmp = str(dest) + ".part"
        def _progress(count, block, total):
            if total > 0:
                pct = int(count * block * 100 / total)
                mb = count * block / 1_048_576
                self._set_status(
                    f"Downloading Godot {GODOT_VER}…  "
                    f"{mb:.1f} MB  ({min(pct,100)}%)")
        urllib.request.urlretrieve(url, tmp, reporthook=_progress)
        os.replace(tmp, dest)

    def _find_godot_binary(self, godot_dir: Path) -> Path:
        exts = [".exe"] if IS_WIN else ([""] if not IS_MAC else [".app/Contents/MacOS/Godot"])
        for f in godot_dir.rglob("*"):
            name = f.name.lower()
            if "godot" in name and any(name.endswith(e) for e in exts):
                return f
        # fallback: any executable
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
            pass  # shortcut is optional

    def _set_status(self, msg: str):
        self._status.set(msg)
        self.update_idletasks()

    def _fail(self, msg: str):
        self._bar.stop()
        self._set_status("Installation failed.")
        self._install_btn.configure(state="normal")
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
        # Re-launch with UAC elevation (needed for shortcut creation)
        ctypes.windll.shell32.ShellExecuteW(
            None, "runas", sys.executable, " ".join(sys.argv), None, 1)
        sys.exit()
    app = Installer()
    app.mainloop()
