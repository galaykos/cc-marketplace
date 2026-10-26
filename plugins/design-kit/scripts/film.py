#!/usr/bin/env python3
"""film.py — the measurable half of design-kit:film: tools, beat grid, cuts, sheets, loudness, pops, checks.
Catches: a missing tool, an off-beat cut or action, a text pair under 4.5:1, an on-screen line or number not traced to facts.json,
a wrong duration/fps/size/codec, a moov atom after mdat, loudness off target, a single-frame pop. Misses: whether the film is good."""
import argparse
import json
import math
import os
import random
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import wave

EXIT_OK, EXIT_FAIL, EXIT_USAGE, EXIT_MISSING = 0, 1, 2, 3


def die(msg, code=EXIT_USAGE):
    print(f"film: {msg}", file=sys.stderr)
    sys.exit(code)


def load_json(path, default=None):
    if not os.path.exists(path):
        if default is not None:
            return default
        die(f"{path}: not found")
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except ValueError as exc:
        die(f"{path}: not valid JSON ({exc})")


def save_json(path, data):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    os.replace(tmp, path)


def need(tool):
    path = shutil.which(tool)
    if not path:
        die(f"{tool} not found on PATH — run `film.py doctor` for the install line", EXIT_MISSING)
    return path


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True)


BROWSER_NAMES = ("google-chrome", "google-chrome-stable", "chromium", "chromium-browser", "chrome", "msedge")


def find_browser():
    for name in BROWSER_NAMES:
        if shutil.which(name):
            return shutil.which(name)
    for base in (os.path.expanduser("~/.cache/ms-playwright"), os.path.expanduser("~/Library/Caches/ms-playwright"),
                 os.path.expanduser("~/.cache/puppeteer")):
        if os.path.isdir(base):
            hits = sorted(d for d in os.listdir(base) if d.startswith(("chromium", "chrome")))
            if hits:
                return os.path.join(base, hits[-1])
    return None


def cmd_doctor(a):
    rows, missing = [], 0

    def row(ok, tool, detail):
        nonlocal missing
        missing += 0 if ok else 1
        rows.append(f"{'ok     ' if ok else 'missing'} {tool:11} {detail}")

    node = shutil.which("node")
    if node:
        ver = run([node, "--version"]).stdout.strip()
        major = int(re.match(r"v(\d+)", ver).group(1)) if re.match(r"v(\d+)", ver) else 0
        floor = 22 if a.renderer == "hyperframes" else 18
        row(major >= floor, "node", f"{ver} (the {a.renderer} path needs ≥ {floor})")
    else:
        row(False, "node", "not on PATH")
    for tool in ("ffmpeg", "ffprobe"):
        path = shutil.which(tool)
        row(bool(path), tool, path or "not on PATH")
    if shutil.which("ffmpeg"):
        enc = run(["ffmpeg", "-hide_banner", "-encoders"]).stdout
        flt = run(["ffmpeg", "-hide_banner", "-filters"]).stdout
        for name, hay, why in (("libx264", enc, "H.264 delivery"), ("aac", enc, "AAC 48 kHz audio"),
                               ("loudnorm", flt, "-14 LUFS mastering"), ("tile", flt, "contact sheets")):
            row(re.search(rf"\b{name}\b", hay) is not None, name, f"ffmpeg build carries it ({why})")
    browser = find_browser()
    row(bool(browser), "browser", browser or "no Chrome/Chromium on PATH or in the Playwright/puppeteer caches")
    bin_name = "hyperframes" if a.renderer == "hyperframes" else "remotion"
    local = os.path.join(a.dir, "node_modules", ".bin", bin_name)
    row(os.path.exists(local), bin_name, local if os.path.exists(local) else f"not installed under {a.dir}")
    print("\n".join(rows))
    if missing:
        print(f"{missing} missing — install inside {a.dir} where possible, else stop and name them to the user")
        return EXIT_MISSING
    return EXIT_OK


def read_wav_mono(path):
    """Mono float samples in [-1, 1] and the sample rate, from a 16-bit PCM WAV."""
    with wave.open(path, "rb") as w:
        ch, width, rate, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
        if width != 2:
            die(f"{path}: {8 * width}-bit WAV — decode to 16-bit PCM first")
        raw = w.readframes(n)
    vals = struct.unpack(f"<{len(raw) // 2}h", raw)
    if ch == 1:
        return [v / 32768.0 for v in vals], rate
    return [sum(vals[i:i + ch]) / (ch * 32768.0) for i in range(0, len(vals), ch)], rate


def decode_to_wav(path):
    """Any audio or video file → a temp mono 16-bit WAV through ffmpeg."""
    need("ffmpeg")
    fd, out = tempfile.mkstemp(suffix=".wav")
    os.close(fd)
    res = run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", path, "-vn", "-ac", "1",
               "-ar", "22050", "-c:a", "pcm_s16le", out])
    if res.returncode != 0:
        die(f"{path}: ffmpeg could not decode it: {res.stderr.strip()[:200]}")
    return out


def audio_samples(path):
    if path.lower().endswith(".wav"):
        try:
            return read_wav_mono(path)
        except wave.Error:
            pass
    tmp = decode_to_wav(path)
    try:
        return read_wav_mono(tmp)
    finally:
        os.unlink(tmp)


def onset_envelope(samples, rate, hop):
    """Half-wave-rectified RMS flux per hop — kicks and hits stand out, sustained pads and quiet hats do not."""
    energies = []
    for i in range(0, len(samples) - hop, hop):
        energies.append(math.sqrt(sum(s * s for s in samples[i:i + hop]) / hop))
    if not energies:
        return [], []
    floor = min(energies)  # a hit at sample 0 rises from silence, not from a previous hop
    env = [energies[0] - floor] + [max(0.0, energies[i] - energies[i - 1]) for i in range(1, len(energies))]
    return env, energies


def detect_beats(samples, rate, lo_bpm=60, hi_bpm=200):
    hop = max(64, rate // 200)  # ~5 ms
    env, energies = onset_envelope(samples, rate, hop)
    hop_s = hop / rate
    lags = range(int(60 / hi_bpm / hop_s), int(60 / lo_bpm / hop_s) + 2)
    if len(env) <= lags[-1] * 2:
        die("audio too short to estimate a tempo", EXIT_FAIL)
    raw = {lag: sum(env[i] * env[i - lag] for i in range(lag, len(env))) / (len(env) - lag) for lag in lags}
    # Log-normal tempo prior around 120 BPM (0.8 octave): it breaks the half/double-tempo tie.
    scored = {lag: raw[lag] * math.exp(-0.5 * (math.log2(60 / (lag * hop_s) / 120) / 0.8) ** 2) for lag in lags}
    best = max(lags[1:-1], key=lambda lag: scored[lag])
    l, c, r = raw[best - 1], raw[best], raw[best + 1]
    denom = l - 2 * c + r
    period = best + (0.5 * (l - r) / denom if denom else 0.0)
    phase = max(range(best), key=lambda p: sum(env[min(len(env) - 1, round(p + k * period))]
                                               for k in range(int((len(env) - p) / period))))
    win, strong = max(1, int(period / 4)), 0.1 * max(env)
    pos = float(phase)
    while pos - period + win >= 0:
        pos -= period
    beats = []
    while pos < len(env):
        lo, hi = max(0, round(pos - win)), min(len(env), round(pos + win) + 1)
        top = max(env[lo:hi])
        peak = next(j for j in range(lo, hi) if env[j] >= 0.5 * top)  # the attack, not the flux maximum
        hit = env[peak] >= strong
        beats.append(round((peak if hit else max(0.0, pos)) * hop_s, 4))
        pos = (peak if hit else pos) + period
    spans = [b - a for a, b in zip(beats, beats[1:])]
    bpm = 60 / (sorted(spans)[len(spans) // 2]) if spans else 60 / (period * hop_s)
    bar_energy = []
    for i in range(0, len(beats) - 4, 4):
        a_i, b_i = int(beats[i] / hop_s), int(beats[i + 4] / hop_s)
        seg = energies[a_i:b_i] or [min(energies)]
        bar_energy.append((beats[i], sum(seg) / len(seg)))
    drop = None
    if len(bar_energy) > 1:
        jumps = [(bar_energy[i][1] - bar_energy[i - 1][1], bar_energy[i][0]) for i in range(1, len(bar_energy))]
        drop = max(jumps)[1]
    return round(bpm, 2), beats, drop


def cmd_beats(a):
    samples, rate = audio_samples(a.audio)
    hint = a.bpm_hint
    if a.verify and not hint:
        hint = (load_json(a.timing).get("music") or {}).get("bpm")
    lo_bpm, hi_bpm = (hint * 0.92, hint * 1.08) if hint else (60, 200)
    bpm, beats, drop = detect_beats(samples, rate, lo_bpm, hi_bpm)
    fps = a.fps
    found = {"bpm": bpm, "beat_times": beats, "beat_frames": [round(t * fps) for t in beats], "drop_time": drop}
    if a.verify:
        timing = load_json(a.timing)
        grid = (timing.get("music") or {}).get("beat_times")
        if not grid:
            die(f"{a.timing}: no music.beat_times to verify against")
        frame = 1.0 / timing.get("fps", fps)
        worst = max(min(abs(g - b) for b in beats) for g in grid if g <= beats[-1] + frame)
        print(json.dumps({"detected_bpm": bpm, "grid_bpm": timing["music"].get("bpm"),
                          "worst_offset_frames": round(worst / frame, 2)}))
        return EXIT_OK if worst <= frame + 1e-6 else EXIT_FAIL
    if a.write:
        timing = load_json(a.timing, {})
        timing.setdefault("fps", fps)
        music = timing.setdefault("music", {})
        music.update({"source": "file", "file": a.audio, **found})
        save_json(a.timing, timing)
    print(json.dumps(found))
    return EXIT_OK


def cmd_peak(a):
    samples, rate = audio_samples(a.audio)
    idx = max(range(len(samples)), key=lambda i: abs(samples[i]))
    print(json.dumps({"peak_offset_s": round(idx / rate, 4), "peak": round(abs(samples[idx]), 4)}))
    return EXIT_OK


def cmd_music(a):
    rng = random.Random(a.seed)
    rate, spb = 48000, 60.0 / a.bpm
    beats_n = a.bars * a.beats_per_bar
    total = int((beats_n * spb + 1.0) * rate)
    left, right = [0.0] * total, [0.0] * total
    roots = [0, 7, 9, 5]  # I–V–vi–IV in semitones over the key root
    key_hz = 110.0

    def add(start, dur, fn, gain, pan=0.0):
        s0 = int(start * rate)
        for i in range(min(int(dur * rate), total - s0)):
            v = fn(i / rate) * gain
            left[s0 + i] += v * (1 - pan)
            right[s0 + i] += v * (1 + pan)

    for b in range(beats_n):
        t0 = b * spb
        add(t0, 0.35, lambda t: math.sin(2 * math.pi * (45 + 75 * math.exp(-t * 30)) * t) * math.exp(-t * 9), 0.9)
        noise = [rng.uniform(-1, 1) for _ in range(int(0.05 * rate))]
        add(t0 + spb / 2, 0.05, lambda t, n=noise: (n[int(t * rate)] - n[max(0, int(t * rate) - 1)])
            * math.exp(-t * 80), 0.18, pan=0.2)
    for bar in range(a.bars):
        root = key_hz * 2 ** (roots[bar % 4] / 12)
        chord = [root, root * 2 ** (4 / 12), root * 2 ** (7 / 12)]
        dur = a.beats_per_bar * spb

        def pad(t, chord=chord, dur=dur):
            env = min(1.0, t / 0.08) * min(1.0, (dur - t) / 0.2)
            return env * sum(2 / math.pi * math.asin(math.sin(2 * math.pi * f * 2 * t)) for f in chord) / 3

        add(bar * dur, dur, pad, 0.22, pan=-0.15)
    peak = max(max(abs(v) for v in left), max(abs(v) for v in right)) or 1.0
    scale = 10 ** (-3 / 20) / peak
    with wave.open(a.out, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(rate)
        frames = bytearray()
        for l, r in zip(left, right):
            frames += struct.pack("<hh", int(max(-1, min(1, l * scale)) * 32767), int(max(-1, min(1, r * scale)) * 32767))
        w.writeframes(bytes(frames))
    beat_times = [round(b * spb, 4) for b in range(beats_n)]
    timing = load_json(a.timing, {})
    timing.setdefault("fps", a.fps)
    timing["music"] = {"source": "synth", "file": a.out, "bpm": a.bpm, "seed": a.seed,
                       "beats_per_bar": a.beats_per_bar, "beat_times": beat_times,
                       "beat_frames": [round(t * timing["fps"]) for t in beat_times],
                       "bar_times": beat_times[::a.beats_per_bar], "duration_s": round(total / rate, 3)}
    save_json(a.timing, timing)
    print(json.dumps({"out": a.out, "bpm": a.bpm, "beats": beats_n, "duration_s": round(total / rate, 3)}))
    return EXIT_OK


def probe(path):
    need("ffprobe")
    res = run(["ffprobe", "-v", "error", "-show_entries",
               "stream=codec_type,codec_name,width,height,avg_frame_rate,pix_fmt,sample_rate:format=duration",
               "-of", "json", path])
    if res.returncode != 0:
        die(f"{path}: ffprobe failed: {res.stderr.strip()[:200]}", EXIT_FAIL)
    return json.loads(res.stdout)


def rate_of(text):
    num, _, den = (text or "0/1").partition("/")
    return float(num) / float(den or 1) if float(den or 1) else 0.0


def cmd_cuts(a):
    need("ffmpeg")
    res = run(["ffmpeg", "-hide_banner", "-i", a.video, "-filter:v", f"select='gt(scene,{a.threshold})',showinfo",
               "-f", "null", "-"])
    cuts = [round(float(m), 3) for m in re.findall(r"pts_time:([0-9.]+)", res.stderr)]
    duration = float(probe(a.video)["format"]["duration"])
    edges = [0.0] + cuts + [duration]
    shots = [{"start": s, "end": e, "len": round(e - s, 3)} for s, e in zip(edges, edges[1:]) if e > s]
    print(json.dumps({"video": a.video, "threshold": a.threshold, "cuts": cuts, "shots": shots}, indent=2))
    return EXIT_OK


def cmd_sheet(a):
    need("ffmpeg")
    duration = float(probe(a.video)["format"]["duration"])
    os.makedirs(a.out, exist_ok=True)
    if a.frames:
        per, every = a.frames, duration / a.frames
    else:
        per, every = a.per, a.every
    cols = a.cols
    rows = math.ceil(per / cols)
    # The first frame of each `every`-long interval, frame 0 included: `fps=` samples mid-interval and drifts the index.
    pick = f"select='isnan(prev_selected_t)+gte(floor(t/{every}),floor(prev_selected_t/{every})+1)'"
    vf = f"{pick},showinfo,scale={a.width}:-2,tile={cols}x{rows}"
    pattern = os.path.join(a.out, "sheet-%03d.png")
    res = run(["ffmpeg", "-hide_banner", "-loglevel", "info", "-y", "-i", a.video, "-vf", vf, "-vsync", "vfr", pattern])
    if res.returncode != 0:
        die(f"ffmpeg sheet failed: {res.stderr.strip()[-200:]}", EXIT_FAIL)
    times = [round(float(t), 3) for t in re.findall(r"Parsed_showinfo.*?pts_time:([0-9.]+)", res.stderr)]
    sheets = sorted(f for f in os.listdir(a.out) if re.match(r"sheet-\d{3}\.png$", f))
    index = [{"sheet": f, "tile_times_s": times[i * per:(i + 1) * per], "every_s": round(every, 4),
              "grid": f"{cols}x{rows}", "order": "row by row, left to right"} for i, f in enumerate(sheets)]
    save_json(os.path.join(a.out, "index.json"), index)
    print(json.dumps({"sheets": len(sheets), "index": os.path.join(a.out, "index.json")}))
    return EXIT_OK


def loudnorm_measure(path, target, tp, lra):
    res = run(["ffmpeg", "-hide_banner", "-i", path, "-vn", "-af",
               f"loudnorm=I={target}:TP={tp}:LRA={lra}:print_format=json", "-f", "null", "-"])
    blocks = re.findall(r"\{[^{}]*\"input_i\"[^{}]*\}", res.stderr)
    if not blocks:
        die(f"{path}: loudnorm printed no measurement: {res.stderr.strip()[-200:]}", EXIT_FAIL)
    return json.loads(blocks[-1])


def cmd_loudness(a):
    need("ffmpeg")
    before = loudnorm_measure(a.input, a.target, a.tp, a.lra)
    if a.out:
        af = (f"loudnorm=I={a.target}:TP={a.tp}:LRA={a.lra}:measured_I={before['input_i']}:"
              f"measured_TP={before['input_tp']}:measured_LRA={before['input_lra']}:"
              f"measured_thresh={before['input_thresh']}:offset={before['target_offset']}:linear=true")
        has_video = any(s["codec_type"] == "video" for s in probe(a.input).get("streams", []))
        cmd = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", a.input, "-af", af, "-ar", "48000"]
        if a.out.lower().endswith((".mp4", ".m4a", ".mov")):
            cmd += ["-c:a", "aac", "-b:a", "192k"]
            cmd += ["-c:v", "copy", "-movflags", "+faststart"] if has_video else ["-vn"]
        cmd.append(a.out)
        res = run(cmd)
        if res.returncode != 0:
            die(f"ffmpeg loudnorm pass 2 failed: {res.stderr.strip()[:200]}", EXIT_FAIL)
    after = loudnorm_measure(a.out, a.target, a.tp, a.lra) if a.out else before
    report = {"target_lufs": a.target, "ceiling_dbtp": a.tp,
              "before": {"lufs": float(before["input_i"]), "true_peak": float(before["input_tp"])},
              "after": {"lufs": float(after["input_i"]), "true_peak": float(after["input_tp"])}}
    print(json.dumps(report))
    ok = abs(report["after"]["lufs"] - a.target) <= 1.0 and report["after"]["true_peak"] <= a.tp + 0.1
    return EXIT_OK if ok else EXIT_FAIL


def cmd_pops(a):
    """Single-frame pops: a frame whose difference from both neighbours spikes past `ratio` x the local median."""
    need("ffmpeg")
    w, h = 96, 54
    proc = subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", a.video, "-vf", f"scale={w}:{h}",
                           "-f", "rawvideo", "-pix_fmt", "gray", "-"], capture_output=True)
    if proc.returncode != 0:
        die(f"ffmpeg decode failed: {proc.stderr.decode()[:200]}", EXIT_FAIL)
    size = w * h
    frames = [proc.stdout[i:i + size] for i in range(0, len(proc.stdout) - size + 1, size)]
    diffs = [sum(abs(x - y) for x, y in zip(frames[i], frames[i - 1])) / size for i in range(1, len(frames))]
    fps = rate_of(next(s["avg_frame_rate"] for s in probe(a.video)["streams"] if s["codec_type"] == "video"))
    pops = []
    for i in range(1, len(diffs) - 1):
        local = sorted(diffs[max(0, i - 6):i - 1] + diffs[i + 2:i + 8]) or [0.0]
        base = max(local[len(local) // 2], 0.5)
        if diffs[i - 1] > a.ratio * base and diffs[i] > a.ratio * base:
            pops.append({"frame": i, "t": round(i / fps, 3) if fps else None, "diff": round(diffs[i - 1], 2)})
    print(json.dumps({"frames": len(frames), "pops": pops}))
    return EXIT_FAIL if pops else EXIT_OK


def luminance(hexcolor):
    h = hexcolor.lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    if not re.fullmatch(r"[0-9a-fA-F]{6}", h):
        raise ValueError(f"not a hex colour: {hexcolor}")
    chans = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in chans]
    return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]


def contrast(fg, bg):
    l1, l2 = sorted((luminance(fg), luminance(bg)), reverse=True)
    return (l1 + 0.05) / (l2 + 0.05)


NUM = re.compile(r"\d[\d.,]*")


def norm_num(tok):
    return tok.rstrip(".,").replace(",", "")


def moov_before_mdat(path):
    order = []
    with open(path, "rb") as fh:
        size_total = os.fstat(fh.fileno()).st_size
        pos = 0
        while pos + 8 <= size_total and len(order) < 64:
            fh.seek(pos)
            size, kind = struct.unpack(">I4s", fh.read(8))
            if size == 1:
                size = struct.unpack(">Q", fh.read(8))[0]
            elif size == 0:
                size = size_total - pos
            order.append(kind.decode("latin-1"))
            if size < 8:
                break
            pos += size
    if "moov" not in order or "mdat" not in order:
        return None
    return order.index("moov") < order.index("mdat")


def cmd_check(a):
    d = a.dir
    timing = load_json(os.path.join(d, "timing.json"))
    facts = load_json(os.path.join(d, "facts.json"))
    style = load_json(os.path.join(d, "style.json"), {})
    fps = timing.get("fps") or die("timing.json: fps missing")
    frame = 1.0 / fps
    results = []

    def res(name, ok, detail):
        results.append({"check": name, "ok": ok, "detail": detail})

    fact_by_id = {str(f.get("id")): f for f in (facts.get("facts", facts) if isinstance(facts, dict) else facts)}
    for t in timing.get("text", []):
        line, fid = t.get("text", ""), str(t.get("fact", ""))
        if fid not in fact_by_id:
            res("facts", False, f"untraced line {line!r} (fact {fid or 'missing'})")
            continue
        source = fact_by_id[fid].get("original", "") + " " + fact_by_id[fid].get("text", "")
        have = {norm_num(n) for n in NUM.findall(source)}
        stray = [n for n in NUM.findall(line) if norm_num(n) not in have]
        res("facts", not stray, f"{line!r} ← fact {fid}" + (f"; numbers not in the source: {stray}" if stray else ""))
        dur, words = t.get("end", 0) - t.get("start", 0), len(line.split())
        floor = max(0.7, 0.3 * words)
        res("hold", dur + 1e-6 >= floor, f"{line!r} held {dur:.2f}s, needs ≥ {floor:.2f}s")
    silent = timing.get("sound") == "silent"
    beats = (timing.get("music") or {}).get("beat_times") or []
    if not silent:
        if not beats:
            res("sync", False, "no music.beat_times in timing.json (sound is not silent)")
        for s in timing.get("scenes", []):
            if s.get("cut", "hard") == "hard" and s.get("start", 0) > 0:
                off = min(abs(s["start"] - b) for b in beats) if beats else float("inf")
                res("sync", off <= frame + 1e-6, f"hard cut into {s.get('id')} at {s['start']}s is {off / frame:.2f} frames off the beat")
        for act in timing.get("actions", []):
            off = min(abs(act["t"] - b) for b in beats) if beats else float("inf")
            res("sync", off <= frame + 1e-6, f"action {act.get('id', act['t'])} at {act['t']}s is {off / frame:.2f} frames off the beat")
    colors = style.get("colors", {})
    for pair in style.get("text_pairs", []):
        fg, bg = (colors.get(c, c) for c in pair[:2])
        try:
            ratio = contrast(fg, bg)
            res("contrast", ratio >= 4.5, f"{pair[0]} on {pair[1]} = {ratio:.2f}:1")
        except ValueError as exc:
            res("contrast", False, str(exc))
    if len(colors) > 6:
        res("palette", False, f"{len(colors)} colours declared in style.json; the style lock allows 6")
    formats = {f["name"]: f for f in timing.get("formats", [])}
    for t in timing.get("text", []):
        box, fmt = t.get("box"), formats.get(t.get("format", ""))
        if box and fmt:
            bottom = box["y"] + box["h"]
            res("safe", bottom <= fmt["height"] * 0.92, f"{t.get('text')!r} ends at y={bottom}, player covers below {fmt['height'] * 0.92:.0f}")
    by_fmt = {}
    for t in timing.get("text", []):
        if t.get("box"):
            by_fmt.setdefault(t.get("format", ""), []).append(t)
    for items in by_fmt.values():
        for i, p in enumerate(items):
            for q in items[i + 1:]:
                in_time = p["start"] < q["end"] and q["start"] < p["end"]
                bp, bq = p["box"], q["box"]
                in_space = bp["x"] < bq["x"] + bq["w"] and bq["x"] < bp["x"] + bp["w"] and bp["y"] < bq["y"] + bq["h"] and bq["y"] < bp["y"] + bp["h"]
                if in_time and in_space:
                    res("overlap", False, f"{p.get('text')!r} and {q.get('text')!r} share space at {max(p['start'], q['start'])}s")
    for video in a.video or []:
        fmt = next((f for f in formats.values() if f.get("file") and os.path.basename(f["file"]) == os.path.basename(video)), None)
        info = probe(video)
        vs = next((s for s in info["streams"] if s["codec_type"] == "video"), {})
        aus = next((s for s in info["streams"] if s["codec_type"] == "audio"), None)
        dur = float(info["format"]["duration"])
        want = timing.get("duration_s")
        if want:
            res("probe", abs(dur - want) <= frame + 1e-6, f"{video}: duration {dur:.3f}s, brief {want}s")
        res("probe", abs(rate_of(vs.get("avg_frame_rate")) - fps) < 0.01, f"{video}: {rate_of(vs.get('avg_frame_rate')):.3f} fps, brief {fps}")
        res("probe", vs.get("codec_name") == "h264" and vs.get("pix_fmt") == "yuv420p", f"{video}: {vs.get('codec_name')} {vs.get('pix_fmt')}")
        if fmt:
            res("probe", (vs.get("width"), vs.get("height")) == (fmt["width"], fmt["height"]), f"{video}: {vs.get('width')}x{vs.get('height')}, format {fmt['width']}x{fmt['height']}")
        if not silent:
            ok = bool(aus) and aus.get("codec_name") == "aac" and aus.get("sample_rate") == "48000"
            res("probe", ok, f"{video}: audio {aus.get('codec_name') if aus else 'none'} {aus.get('sample_rate') if aus else ''}")
        fast = moov_before_mdat(video)
        res("probe", fast is True, f"{video}: moov {'before' if fast else 'after' if fast is False else 'not found relative to'} mdat")
    failed = [r for r in results if not r["ok"]]
    if a.ledger:
        with open(a.ledger, "a", encoding="utf-8") as fh:
            fh.write(f"\n## round {a.round} — film.py check: {len(results) - len(failed)}/{len(results)} pass\n")
            for r in results:
                fh.write(f"{'PASS' if r['ok'] else 'FAIL'} {r['check']}: {r['detail']}\n")
    for r in results:
        if not r["ok"] or a.verbose:
            print(f"{'PASS' if r['ok'] else 'FAIL'} {r['check']}: {r['detail']}")
    print(f"{len(results) - len(failed)}/{len(results)} checks pass")
    return EXIT_FAIL if failed else EXIT_OK


def main(argv=None):
    p = argparse.ArgumentParser(prog="film.py", description="Measurable steps of design-kit:film. Exit 0 ok, 1 a check failed, 2 usage, 3 a tool is missing.")
    sub = p.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("doctor", help="node, ffmpeg (+libx264, aac, loudnorm, tile), a headless browser, the renderer")
    s.add_argument("--renderer", choices=("hyperframes", "remotion"), default="hyperframes")
    s.add_argument("--dir", default=".")
    s = sub.add_parser("music", help="synthesize a beat-gridded WAV and write the grid into timing.json")
    s.add_argument("--bpm", type=float, default=120.0)
    s.add_argument("--bars", type=int, default=8)
    s.add_argument("--beats-per-bar", type=int, default=4)
    s.add_argument("--fps", type=int, default=60)
    s.add_argument("--seed", type=int, default=1)
    s.add_argument("--out", required=True)
    s.add_argument("--timing", required=True)
    s = sub.add_parser("beats", help="tempo, beats and drop of an audio file; --write stores them, --verify checks a grid")
    s.add_argument("audio")
    s.add_argument("--fps", type=int, default=60)
    s.add_argument("--timing", default="timing.json")
    s.add_argument("--bpm-hint", type=float, help="search only ±8%% around this tempo (--verify uses the grid's)")
    g = s.add_mutually_exclusive_group()
    g.add_argument("--write", action="store_true")
    g.add_argument("--verify", action="store_true")
    s = sub.add_parser("peak", help="where a sound effect's peak sits after its file start")
    s.add_argument("audio")
    s = sub.add_parser("cuts", help="scene cuts and shot lengths of a reference video")
    s.add_argument("video")
    s.add_argument("--threshold", type=float, default=0.3)
    s = sub.add_parser("sheet", help="contact sheets: a frame every --every s, --per to a sheet; or --frames N in one sheet")
    s.add_argument("video")
    s.add_argument("--out", required=True)
    s.add_argument("--every", type=float, default=0.2)
    s.add_argument("--per", type=int, default=20)
    s.add_argument("--cols", type=int, default=5)
    s.add_argument("--frames", type=int)
    s.add_argument("--width", type=int, default=384)
    s = sub.add_parser("loudness", help="measure, and with --out master to --target LUFS under --tp dBTP (re-measured after encode)")
    s.add_argument("input")
    s.add_argument("--out")
    s.add_argument("--target", type=float, default=-14.0)
    s.add_argument("--tp", type=float, default=-1.0)
    s.add_argument("--lra", type=float, default=11.0)
    s = sub.add_parser("pops", help="single-frame pops in a rendered video")
    s.add_argument("video")
    s.add_argument("--ratio", type=float, default=3.0)
    s = sub.add_parser("check", help="facts, holds, beat sync, contrast, safe area, overlap, and --video probes")
    s.add_argument("--dir", default=".")
    s.add_argument("--video", action="append")
    s.add_argument("--ledger")
    s.add_argument("--round", type=int, default=1)
    s.add_argument("--verbose", action="store_true")
    a = p.parse_args(argv)
    return {"doctor": cmd_doctor, "music": cmd_music, "beats": cmd_beats, "peak": cmd_peak, "cuts": cmd_cuts,
            "sheet": cmd_sheet, "loudness": cmd_loudness, "pops": cmd_pops, "check": cmd_check}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
