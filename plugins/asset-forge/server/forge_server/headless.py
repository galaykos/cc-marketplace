"""Run one job in a background Blender process and collect its JSON result. Never opens the user's working file:
callers pass a snapshot path, or nothing for a factory-startup scene."""
import glob
import json
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

RUNNER = Path(__file__).with_name("runner.py")
LOG_TAIL_LINES = 40


def _natural_key(path):
    return [int(part) if part.isdigit() else part for part in re.split(r"(\d+)", path)]


def _install_candidates():
    home = os.path.expanduser("~")
    found = sorted(glob.glob(f"{home}/Applications/blender-*/blender"), key=_natural_key, reverse=True)
    found += sorted(glob.glob("/opt/blender*/blender"), key=_natural_key, reverse=True)
    found += ["/Applications/Blender.app/Contents/MacOS/Blender", "/snap/bin/blender", "/usr/bin/blender"]
    found += sorted(glob.glob("C:/Program Files/Blender Foundation/Blender */blender.exe"), key=_natural_key, reverse=True)
    return found


def _executable(path):
    p = Path(os.path.expanduser(path))
    return p.is_file() and os.access(p, os.X_OK)


def find_blender():
    """Return (path, source), or (None, reason). Order: the userConfig value, BLENDER_PATH, PATH, install folders."""
    for var, label in (("FORGE_BLENDER_PATH", "userConfig blender_path"), ("BLENDER_PATH", "BLENDER_PATH")):
        value = os.environ.get(var, "").strip()
        if value:
            if _executable(value):
                return os.path.expanduser(value), label
            return None, f"{label} = {value} is not an executable file"
    on_path = shutil.which("blender")
    if on_path:
        return on_path, "PATH"
    for candidate in _install_candidates():
        if _executable(candidate):
            return candidate, "install folder"
    return None, "no Blender found: set blender_path in /config, or BLENDER_PATH, or put blender on PATH"


def _tail(*streams):
    text = "\n".join(s if isinstance(s, str) else (s or b"").decode("utf-8", "replace") for s in streams if s)
    return "\n".join(text.strip().splitlines()[-LOG_TAIL_LINES:])


def _fingerprint(path):
    if not path:
        return None
    st = Path(path).stat()
    return st.st_size, st.st_mtime_ns


def run_job(op, args=None, blend_path=None, timeout=300):
    """Run runner.py's `op` with `args` (a JSON-serialisable dict). timeout is in seconds. Returns the runner's dict,
    or {"ok": False, "stage", "error", "blender_log_tail"} for any failure outside it."""
    exe, source = find_blender()
    if not exe:
        return {"ok": False, "stage": "locate-blender", "error": source}
    if blend_path and not Path(blend_path).is_file():
        return {"ok": False, "stage": "input", "error": f"blend_path does not exist: {blend_path}"}
    before = _fingerprint(blend_path)
    with tempfile.TemporaryDirectory(prefix="asset-forge-") as tmp:
        request = Path(tmp, "request.json")
        result = Path(tmp, "result.json")
        request.write_text(json.dumps({"op": op, "args": args or {}, "result_path": str(result)}))
        cmd = [exe, "-b", "--factory-startup"]
        if blend_path:
            cmd.append(str(blend_path))
        cmd += ["--python-exit-code", "1", "--python", str(RUNNER), "--", str(request)]
        env = dict(os.environ)
        env["WAYLAND_DISPLAY"] = ""  # Blender 5.x in -b mode on a Wayland desktop still probes the display and can stall
        try:
            proc = subprocess.run(cmd, capture_output=True, timeout=timeout, env=env)
        except subprocess.TimeoutExpired as exc:
            return {"ok": False, "stage": "timeout", "error": f"Blender did not finish within {timeout} s",
                    "blender_log_tail": _tail(exc.stdout, exc.stderr)}
        except OSError as exc:
            return {"ok": False, "stage": "launch", "error": f"{exe}: {exc}"}
        log_tail = _tail(proc.stdout, proc.stderr)
        if not result.is_file():
            return {"ok": False, "stage": "blender", "error": f"Blender exited {proc.returncode} without writing a result",
                    "blender_log_tail": log_tail}
        try:
            out = json.loads(result.read_text())
        except ValueError as exc:
            return {"ok": False, "stage": "result", "error": f"unreadable result JSON: {exc}", "blender_log_tail": log_tail}
    if before != _fingerprint(blend_path):
        out = {"ok": False, "stage": "source-modified", "error": f"the job changed {blend_path}; headless jobs must "
               "work on a snapshot and never save over it", "job_result": out}
    out["blender"] = {"path": exe, "found_by": source}
    if not out.get("ok"):
        out["blender_log_tail"] = log_tail
    return out
