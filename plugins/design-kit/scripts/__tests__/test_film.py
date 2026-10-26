import importlib.util
import json
import math
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
import wave
from pathlib import Path

FILM = Path(__file__).resolve().parents[1] / "film.py"
spec = importlib.util.spec_from_file_location("film", FILM)
film = importlib.util.module_from_spec(spec)
spec.loader.exec_module(film)
HAVE_FFMPEG = bool(shutil.which("ffmpeg") and shutil.which("ffprobe"))


def run(*args, env=None):
    return subprocess.run([sys.executable, "-I", str(FILM), *args], capture_output=True, text=True, env=env)


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def write(self, name, data):
        (self.tmp / name).write_text(json.dumps(data))


class Doctor(Base):
    def test_missing_tools_exit_3_and_named(self):
        empty = self.tmp / "bin"
        empty.mkdir()
        res = run("doctor", "--dir", str(self.tmp), env={"PATH": str(empty), "HOME": str(self.tmp)})
        self.assertEqual(res.returncode, 3, res.stdout + res.stderr)
        for tool in ("node", "ffmpeg", "ffprobe", "browser", "hyperframes"):
            self.assertRegex(res.stdout, rf"missing\s+{tool}\b")


class MusicAndBeats(Base):
    def synth(self, bpm, bars=4):
        wav, timing = self.tmp / f"m{bpm}.wav", self.tmp / f"t{bpm}.json"
        res = run("music", "--bpm", str(bpm), "--bars", str(bars), "--out", str(wav), "--timing", str(timing))
        self.assertEqual(res.returncode, 0, res.stderr)
        return wav, timing

    def test_music_writes_48k_stereo_and_the_grid(self):
        wav, timing = self.synth(120)
        with wave.open(str(wav)) as w:
            self.assertEqual((w.getframerate(), w.getnchannels(), w.getsampwidth()), (48000, 2, 2))
        music = json.loads(timing.read_text())["music"]
        self.assertEqual(len(music["beat_times"]), 16)
        self.assertEqual(music["beat_frames"][1], 30)
        self.assertEqual(music["bar_times"], [0.0, 2.0, 4.0, 6.0])

    def test_detection_lands_within_a_frame_of_the_grid_across_tempos(self):
        for bpm in (70, 90, 128, 174):
            wav, timing = self.synth(bpm)
            res = run("beats", str(wav), "--timing", str(timing), "--verify")
            self.assertEqual(res.returncode, 0, f"{bpm}: {res.stdout}")
            self.assertLessEqual(json.loads(res.stdout)["worst_offset_frames"], 1.0)

    def test_a_grid_shifted_off_the_kicks_fails_verify(self):
        wav, timing = self.synth(120)
        data = json.loads(timing.read_text())
        data["music"]["beat_times"] = [t + 0.1 for t in data["music"]["beat_times"]]
        timing.write_text(json.dumps(data))
        res = run("beats", str(wav), "--timing", str(timing), "--verify")
        self.assertEqual(res.returncode, 1, res.stdout)

    def test_write_stores_detected_beats(self):
        wav, _ = self.synth(110)
        timing = self.tmp / "detected.json"
        res = run("beats", str(wav), "--timing", str(timing), "--write", "--bpm-hint", "110")
        self.assertEqual(res.returncode, 0, res.stderr)
        music = json.loads(timing.read_text())["music"]
        self.assertEqual(music["source"], "file")
        self.assertAlmostEqual(music["bpm"], 110, delta=1)

    def test_peak_reports_offset_after_file_start(self):
        path = self.tmp / "click.wav"
        rate = 48000
        samples = [0] * rate
        for i in range(200):
            samples[12000 + i] = int(20000 * math.exp(-i / 40))
        with wave.open(str(path), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(rate)
            w.writeframes(struct.pack(f"<{len(samples)}h", *samples))
        res = run("peak", str(path))
        self.assertAlmostEqual(json.loads(res.stdout)["peak_offset_s"], 0.25, delta=0.001)


class Check(Base):
    def base(self, **over):
        facts = {"facts": [{"id": "f1", "text": "Cuts reporting to 15 minutes", "original": "Teams cut weekly reporting from 4 hours to 15 minutes.", "url": "https://example.com"}]}
        timing = {"fps": 60, "duration_s": 6, "sound": "music",
                  "formats": [{"name": "16x9", "width": 1920, "height": 1080}],
                  "music": {"bpm": 120, "beat_times": [0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0]},
                  "scenes": [{"id": "s1", "start": 0, "cut": "hard"}, {"id": "s2", "start": 2.0, "cut": "hard"}],
                  "actions": [{"id": "click", "t": 1.5}],
                  "text": [{"text": "Reporting in 15 minutes", "fact": "f1", "start": 0.2, "end": 2.0, "format": "16x9",
                            "box": {"x": 100, "y": 100, "w": 800, "h": 120}}]}
        style = {"colors": {"ink": "#101014", "paper": "#ffffff"}, "text_pairs": [["ink", "paper"]]}
        for key, val in over.items():
            target, _, field = key.partition("__")
            {"timing": timing, "facts": facts, "style": style}[target][field] = val
        self.write("timing.json", timing)
        self.write("facts.json", facts)
        self.write("style.json", style)
        return run("check", "--dir", str(self.tmp), "--ledger", str(self.tmp / "ledger.txt"), "--round", "2")

    def test_clean_film_passes_and_ledgers_the_round(self):
        res = self.base()
        self.assertEqual(res.returncode, 0, res.stdout)
        ledger = (self.tmp / "ledger.txt").read_text()
        self.assertIn("## round 2", ledger)
        self.assertIn("PASS facts", ledger)

    def test_untraced_line_and_invented_number_fail(self):
        res = self.base(timing__text=[
            {"text": "Loved by teams", "start": 0, "end": 2},
            {"text": "Cut reporting by 45%", "fact": "f1", "start": 2, "end": 4}])
        self.assertEqual(res.returncode, 1)
        self.assertIn("untraced line", res.stdout)
        self.assertIn("numbers not in the source: ['45']", res.stdout)

    def test_short_hold_fails(self):
        res = self.base(timing__text=[{"text": "Reporting in 15 minutes now", "fact": "f1", "start": 0, "end": 1.0}])
        self.assertEqual(res.returncode, 1)
        self.assertIn("needs ≥ 1.50s", res.stdout)

    def test_off_beat_cut_and_action_fail_and_silent_skips_sync(self):
        res = self.base(timing__scenes=[{"id": "s2", "start": 2.1, "cut": "hard"}], timing__actions=[{"id": "tap", "t": 1.2}])
        self.assertEqual(res.returncode, 1)
        self.assertIn("hard cut into s2", res.stdout)
        self.assertIn("action tap", res.stdout)
        self.assertEqual(self.base(timing__sound="silent", timing__scenes=[{"id": "s2", "start": 2.1}]).returncode, 0)

    def test_contrast_threshold_and_palette_cap(self):
        res = self.base(style__colors={"grey": "#777777", "paper": "#ffffff"}, style__text_pairs=[["grey", "paper"]])
        self.assertEqual(res.returncode, 1)
        self.assertIn("grey on paper = 4.48:1", res.stdout)
        self.assertEqual(self.base(style__colors={"grey": "#767676", "paper": "#ffffff"}, style__text_pairs=[["grey", "paper"]]).returncode, 0)
        seven = {f"c{i}": "#000000" for i in range(7)}
        self.assertIn("allows 6", self.base(style__colors=seven, style__text_pairs=[]).stdout)

    def test_safe_area_and_overlap_fail(self):
        low = {"text": "Reporting in 15 minutes", "fact": "f1", "start": 0, "end": 2, "format": "16x9", "box": {"x": 100, "y": 960, "w": 800, "h": 80}}
        res = self.base(timing__text=[low])
        self.assertIn("player covers below 994", res.stdout)
        a = {"text": "Reporting in 15 minutes", "fact": "f1", "start": 0, "end": 2, "format": "16x9", "box": {"x": 100, "y": 100, "w": 800, "h": 120}}
        b = dict(a, start=1.0, end=3.0, box={"x": 500, "y": 150, "w": 400, "h": 100})
        self.assertIn("share space", self.base(timing__text=[a, b]).stdout)

    def test_contrast_math_matches_wcag(self):
        self.assertAlmostEqual(film.contrast("#000000", "#ffffff"), 21.0, places=2)
        self.assertAlmostEqual(film.contrast("#767676", "#fff"), 4.54, places=2)


class Faststart(Base):
    def mp4(self, *boxes):
        path = self.tmp / "f.mp4"
        path.write_bytes(b"".join(struct.pack(">I4s", 8 + len(body), kind) + body for kind, body in boxes))
        return str(path)

    def test_moov_order(self):
        self.assertTrue(film.moov_before_mdat(self.mp4((b"ftyp", b"isom0000"), (b"moov", b""), (b"mdat", b"xx"))))
        self.assertFalse(film.moov_before_mdat(self.mp4((b"ftyp", b"isom0000"), (b"mdat", b"xx"), (b"moov", b""))))
        self.assertIsNone(film.moov_before_mdat(self.mp4((b"ftyp", b"isom0000"), (b"mdat", b"xx"))))


@unittest.skipUnless(HAVE_FFMPEG, "ffmpeg/ffprobe not on PATH: sheet, cuts, loudness, pops and probe cases not run")
class WithFfmpeg(Base):
    def setUp(self):
        super().setUp()
        self.video = str(self.tmp / "clip.mp4")
        res = subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                              "-f", "lavfi", "-i", "testsrc2=size=320x180:rate=30:duration=6",
                              "-f", "lavfi", "-i", "sine=frequency=440:duration=6:sample_rate=48000",
                              "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac", "-ar", "48000",
                              "-movflags", "+faststart", "-shortest", self.video], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, res.stderr)

    def clip(self, name, vf_or_graph, *inputs):
        path = str(self.tmp / name)
        args = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y"]
        for src in inputs:
            args += ["-f", "lavfi", "-i", src]
        args += (["-filter_complex", vf_or_graph, "-map", "[v]"] if "[v]" in vf_or_graph else ["-vf", vf_or_graph])
        res = subprocess.run(args + ["-c:v", "libx264", "-pix_fmt", "yuv420p", path], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, res.stderr)
        return path

    def test_sheet_tiles_start_at_zero_on_the_interval(self):
        res = run("sheet", self.video, "--out", str(self.tmp / "sheets"), "--every", "0.5", "--per", "6", "--cols", "3")
        self.assertEqual(res.returncode, 0, res.stderr)
        index = json.loads((self.tmp / "sheets" / "index.json").read_text())
        self.assertEqual(len(index), 2)
        self.assertEqual(index[0]["grid"], "3x2")
        self.assertEqual(index[0]["tile_times_s"], [0.0, 0.5, 1.0, 1.5, 2.0, 2.5])
        self.assertEqual(index[1]["tile_times_s"][0], 3.0)
        one = json.loads(run("sheet", self.video, "--out", str(self.tmp / "one"), "--frames", "16").stdout)
        self.assertEqual(one["sheets"], 1)
        times = json.loads((self.tmp / "one" / "index.json").read_text())[0]["tile_times_s"]
        self.assertEqual(len(times), 16)
        for k, t in enumerate(times):  # each tile is the first frame at or after k x 0.375 s, frame 0 included
            self.assertTrue(k * 0.375 - 1e-3 <= t <= k * 0.375 + 1 / 30 + 1e-3, f"tile {k} at {t}s")
            self.assertAlmostEqual(t * 30, round(t * 30), delta=0.05, msg=f"tile {k}: {t}s is not a source frame's time")

    def test_cuts_finds_a_real_cut(self):
        self.assertEqual(json.loads(run("cuts", self.video).stdout)["cuts"], [])
        cut = self.clip("cut.mp4", "[0:v][1:v]concat=n=2:v=1[v]", "testsrc2=size=320x180:rate=30:duration=2",
                        "smptebars=size=320x180:rate=30:duration=2")
        found = json.loads(run("cuts", cut).stdout)
        self.assertEqual(len(found["cuts"]), 1)
        self.assertAlmostEqual(found["cuts"][0], 2.0, delta=0.05)
        self.assertAlmostEqual(found["shots"][-1]["end"], 4.0, delta=0.1)

    def test_loudness_masters_to_target(self):
        out = str(self.tmp / "mastered.m4a")
        res = run("loudness", self.video, "--out", out)
        self.assertEqual(res.returncode, 0, res.stdout + res.stderr)
        self.assertAlmostEqual(json.loads(res.stdout)["after"]["lufs"], -14, delta=1)

    def test_smooth_clip_has_no_pops_and_a_one_frame_flash_is_one(self):
        self.assertEqual(run("pops", self.video).returncode, 0)
        flash = self.clip("flash.mp4", "drawbox=enable='eq(n,45)':x=0:y=0:w=iw:h=ih:color=white:t=fill",
                          "testsrc2=size=320x180:rate=30:duration=3")
        res = run("pops", flash)
        self.assertEqual(res.returncode, 1, res.stdout)
        self.assertEqual([p["frame"] for p in json.loads(res.stdout)["pops"]], [45])

    def test_probe_checks_pass_on_a_matching_brief(self):
        self.write("timing.json", {"fps": 30, "duration_s": 6, "sound": "music", "music": {"beat_times": [0.0]},
                                   "formats": [{"name": "small", "width": 320, "height": 180, "file": "clip.mp4"}]})
        self.write("facts.json", {"facts": []})
        res = run("check", "--dir", str(self.tmp), "--video", self.video)
        self.assertEqual(res.returncode, 0, res.stdout)


if __name__ == "__main__":
    unittest.main()
