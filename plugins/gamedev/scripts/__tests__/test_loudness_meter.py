"""End-to-end tests for loudness_meter.py on WAV fixtures synthesised here (EBU Tech 3341 V4 test signals and others)."""

from __future__ import annotations

import importlib.util
import io
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
import unittest
import wave
from pathlib import Path

METER = Path(__file__).resolve().parents[1] / "loudness_meter.py"
FFMPEG = shutil.which("ffmpeg")
GUID_TAIL = b"\x00\x00\x00\x00\x10\x00\x80\x00\x00\xaa\x00\x38\x9b\x71"

# Runs the meter with wave as Python 3.10/3.11 shipped it: WAVE_FORMAT_PCM only, "unknown format: 65534" otherwise.
PY311_WAVE = r"""import runpy, struct, sys, wave
real = wave.Wave_read._read_fmt_chunk
class Replay:
    def __init__(self, chunk, head):
        self.chunk, self.head = chunk, head
    def read(self, n):
        if self.head:
            out, self.head = self.head[:n], self.head[n:]
            return out
        return self.chunk.read(n)
def read_fmt_chunk(self, chunk):
    head = chunk.read(14)
    tag = struct.unpack_from("<H", head)[0] if len(head) >= 2 else wave.WAVE_FORMAT_PCM
    if tag != wave.WAVE_FORMAT_PCM:
        raise wave.Error("unknown format: %r" % (tag,))
    real(self, Replay(chunk, head))
wave.Wave_read._read_fmt_chunk = read_fmt_chunk
sys.argv = sys.argv[1:]
runpy.run_path(sys.argv[0], run_name="__main__")
"""
BIG_ENDIAN = "import runpy, sys; sys.byteorder = 'big'; sys.argv = sys.argv[1:]; runpy.run_path(sys.argv[0], run_name='__main__')"


def write_wav(path: Path, rate: int, channels: int, width: int, frames: bytes) -> Path:
    with wave.open(str(path), "wb") as out:
        out.setnchannels(channels)
        out.setsampwidth(width)
        out.setframerate(rate)
        out.writeframes(frames)
    return path


def pcm_wav(path: Path, rate: int, channels: int, width: int, segments, taper: float = 0.0) -> Path:
    """segments: (seconds, frequency, per-channel level as dBFS when <= 0 or as a fraction of full scale, phase degrees)."""
    full = 1 << (width * 8 - 1)
    frames = bytearray()
    start = 0
    for seconds, freq, levels, phase in segments:
        count = round(seconds * rate)
        ramp = round(taper * rate)
        amps = [0.0 if lv is None else (10 ** (lv / 20) if lv <= 0 else lv) for lv in levels]
        period = rate // freq if not ramp and freq and rate % freq == 0 else count
        chunk = bytearray()
        for i in range(min(period, count)):
            gain = min(1.0, i / ramp, (count - 1 - i) / ramp) if ramp else 1.0
            s = math.sin(2 * math.pi * freq * (start + i) / rate + math.radians(phase)) * gain
            for a in amps:
                q = max(-full, min(full - 1, round(a * s * full)))
                chunk += (q + 128 if width == 1 else q).to_bytes(width, "little", signed=width > 1)
        repeats, rest = divmod(count, period)
        frames += chunk * repeats + chunk[:rest * width * channels]
        start += count
    return write_wav(path, rate, channels, width, bytes(frames))


def float_wav(path: Path, rate: int, samples: list[float]) -> Path:
    data = struct.pack(f"<{len(samples)}f", *samples)
    fmt = struct.pack("<HHIIHH", 3, 1, rate, rate * 4, 4, 32)
    body = b"WAVE" + b"fmt " + struct.pack("<I", len(fmt)) + fmt + b"data" + struct.pack("<I", len(data)) + data
    path.write_bytes(b"RIFF" + struct.pack("<I", len(body)) + body)
    return path


def extensible_wav(path: Path, source: Path, subformat: int = 1) -> Path:
    """Re-wrap source's PCM as WAVE_FORMAT_EXTENSIBLE, with an odd-sized LIST chunk before data."""
    with wave.open(str(source), "rb") as src:
        channels, width, rate = src.getnchannels(), src.getsampwidth(), src.getframerate()
        frames = src.readframes(src.getnframes())
    bits = width * 8
    fmt = struct.pack("<HHIIHHHHI", 0xFFFE, channels, rate, rate * channels * width, channels * width, bits, 22, bits, 0)
    fmt += struct.pack("<H", subformat) + GUID_TAIL
    body = (b"WAVE" + b"fmt " + struct.pack("<I", len(fmt)) + fmt + b"LIST" + struct.pack("<I", 5) + b"INFOx\x00"
            + b"data" + struct.pack("<I", len(frames)) + frames)
    path.write_bytes(b"RIFF" + struct.pack("<I", len(body)) + body)
    return path


class LoudnessMeterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tmp = tempfile.TemporaryDirectory()
        cls.root = Path(cls.tmp.name)
        cls.no_ffmpeg = cls.root / "empty-bin"
        cls.no_ffmpeg.mkdir()
        r = cls.root
        stereo = lambda dbfs: [dbfs, dbfs]
        cls.case1 = pcm_wav(r / "case1.wav", 48000, 2, 3, [(2, 1000, stereo(-23), 0)])
        cls.case2 = pcm_wav(r / "case2.wav", 48000, 2, 3, [(2, 1000, stereo(-33), 0)])
        cls.case4 = pcm_wav(r / "case4.wav", 48000, 2, 2, [(10, 1000, stereo(-72), 0), (10, 1000, stereo(-36), 0),
                                                           (60, 1000, stereo(-23), 0), (10, 1000, stereo(-36), 0),
                                                           (10, 1000, stereo(-72), 0)])
        cls.case5 = pcm_wav(r / "case5.wav", 48000, 2, 2, [(20, 1000, stereo(-26), 0), (20.1, 1000, stereo(-20), 0),
                                                           (20, 1000, stereo(-26), 0)])
        cls.case6 = pcm_wav(r / "case6.wav", 48000, 5, 3, [(2, 1000, [-28, -28, -24, -30, -30], 0)])
        cls.tp = {n: pcm_wav(r / f"tp{n}.wav", 48000, 2, 3, [(1, 48000 / div, [amp, amp], phase)], taper=0.01)
                  for n, div, amp, phase in ((15, 4, 0.5, 0), (16, 4, 0.5, 45), (17, 6, 0.5, 60), (18, 8, 0.5, 67.5),
                                             (19, 4, 1.41, 45))}

    @classmethod
    def tearDownClass(cls) -> None:
        cls.tmp.cleanup()

    def run_meter(self, *args, path_env: str | None = None, shim: str | None = None,
                  cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
        env = dict(os.environ)
        if path_env is not None:
            env["PATH"] = path_env
        command = [sys.executable, "-I"] + (["-c", shim] if shim else []) + [str(METER), *map(str, args)]
        return subprocess.run(command, capture_output=True, text=True, env=env, cwd=cwd)

    def report(self, *args, path_env: str | None = None, shim: str | None = None) -> tuple[int, dict]:
        result = self.run_meter(*args, "--json", path_env=path_env, shim=shim)
        self.assertNotIn("Traceback", result.stderr)
        return result.returncode, json.loads(result.stdout)

    def file(self, payload: dict, name: str) -> dict:
        return next(f for f in payload["files"] if Path(f["path"]).name == name)

    def test_ebu_3341_integrated_cases_1_2_4_5_6(self) -> None:
        """Tech 3341 V4 Table 1, I within 0.1 LU. Cases 1, 2 and 6 run 2 s instead of 20 s (a steady tone reads the same); 4 and 5 keep their durations."""
        code, payload = self.report(self.case1, self.case2, self.case4, self.case5, self.case6)
        self.assertEqual((code, payload["errors"]), (0, []))
        for name, expected in (("case1.wav", -23.0), ("case2.wav", -33.0), ("case4.wav", -23.0),
                               ("case5.wav", -23.0), ("case6.wav", -23.0)):
            with self.subTest(case=name):
                self.assertAlmostEqual(self.file(payload, name)["integrated_lufs"], expected, delta=0.1)

    def test_ebu_3341_true_peak_cases_15_to_19(self) -> None:
        """Tech 3341 V4: -6.0 dBTP, +3.0 for case 19, tolerance +0.2/-0.4; case 16's samples peak 3 dB lower."""
        code, payload = self.report(*self.tp.values())
        self.assertEqual(code, 0)
        for n, path in self.tp.items():
            expected = 3.0 if n == 19 else -6.0
            with self.subTest(case=n):
                value = self.file(payload, path.name)["true_peak_dbtp"]
                self.assertTrue(expected - 0.4 <= value <= expected + 0.2, value)

    def test_one_channel_997_hz_reads_3_01_below_its_level_at_every_width_and_44_1_khz(self) -> None:
        """BS.1770-5: a 0 dBFS 997 Hz sine in one channel reads -3.01 LKFS."""
        paths = [pcm_wav(self.root / f"w{w}.wav", 48000, 1, w, [(1, 997, [-10], 0)]) for w in (1, 2, 3, 4)]
        paths.append(pcm_wav(self.root / "r44.wav", 44100, 1, 2, [(1, 997, [-10], 0)]))
        code, payload = self.report(*paths)
        self.assertEqual(code, 0)
        for f in payload["files"]:
            with self.subTest(file=Path(f["path"]).name):
                self.assertAlmostEqual(f["integrated_lufs"], -13.01, delta=0.15 if f["path"].endswith("w1.wav") else 0.05)

    def test_target_presets_and_tolerance(self) -> None:
        code, payload = self.report(self.case1, "--target", "aswg-home")
        self.assertEqual((code, payload["errors"]), (0, []))
        self.assertEqual(payload["target"], {"name": "aswg-home", "lufs": -24.0, "tolerance_lu": 2.0})
        self.assertEqual(payload["max_true_peak_dbtp"], -1.0)
        code, payload = self.report(self.case1, "--target", "aswg-portable")
        self.assertEqual((code, [e["code"] for e in payload["errors"]]), (1, ["loudness-off-target"]))
        self.assertIn("5.0 LU below the aswg-portable target -18 ±2 LUFS", payload["errors"][0]["message"])
        self.assertEqual(self.report(self.case1, "--target", "-22.5")[0], 0)
        code, payload = self.report(self.case1, "--target", "-21.9")
        self.assertEqual((code, payload["target"]["tolerance_lu"]), (1, 1.0))
        self.assertEqual(self.report(self.case1, "--target", "-21.9", "--tolerance", "1.2")[0], 0)

    def test_true_peak_ceiling_sees_the_inter_sample_peak(self) -> None:
        code, payload = self.report(self.tp[16], "--max-true-peak", "-7")
        self.assertEqual((code, [e["code"] for e in payload["errors"]]), (1, ["true-peak-over"]))
        self.assertEqual(self.report(self.tp[16], "--max-true-peak", "-5")[0], 0)

    def test_short_and_silent_files_have_no_integrated_loudness(self) -> None:
        short = pcm_wav(self.root / "click.wav", 48000, 2, 2, [(0.3, 1000, [-6, -6], 0)])
        silent = pcm_wav(self.root / "silence.wav", 48000, 2, 2, [(1, 1000, [None, None], 0)])
        code, payload = self.report(short, silent)
        self.assertEqual((code, payload["errors"]), (0, []))
        self.assertEqual(self.file(payload, "click.wav")["integrated_note"], "shorter than one 400 ms gating block")
        self.assertIsNotNone(self.file(payload, "click.wav")["true_peak_dbtp"])
        quiet = self.file(payload, "silence.wav")
        self.assertEqual((quiet["integrated_lufs"], quiet["true_peak_dbtp"]), (None, None))
        code, payload = self.report(short, "--target", "aswg-home")
        self.assertEqual((code, payload["errors"][0]["code"]), (1, "loudness-off-target"))

    def test_without_ffmpeg_ogg_and_float_wav_exit_3(self) -> None:
        ogg = self.root / "music.ogg"
        ogg.write_bytes(b"OggS\x00\x02" + bytes(30))
        flt = float_wav(self.root / "float.wav", 48000, [0.1] * 4800)
        code, payload = self.report(ogg, flt, self.case1, path_env=str(self.no_ffmpeg))
        self.assertEqual((code, [e["code"] for e in payload["errors"]]), (3, ["needs-ffmpeg", "needs-ffmpeg"]))
        self.assertEqual(len(payload["files"]), 1)

    def test_unreadable_and_unsupported_input_exit_2(self) -> None:
        junk = self.root / "notes.txt"
        junk.write_text("not audio")
        quad = pcm_wav(self.root / "quad.wav", 48000, 4, 2, [(0.5, 1000, [-20] * 4, 0)])
        low = pcm_wav(self.root / "low.wav", 4000, 1, 2, [(0.5, 440, [-20], 0)])
        code, payload = self.report(junk, quad, self.root / "missing.wav", low, path_env=str(self.no_ffmpeg))
        self.assertEqual((code, [e["code"] for e in payload["errors"]]),
                         (2, ["unreadable", "channels-unsupported", "unreadable", "unreadable"]))
        self.assertIn("below 8 kHz", payload["errors"][3]["message"])
        ogg = self.root / "late.ogg"
        ogg.write_bytes(b"OggS")
        self.assertEqual(self.report(junk, ogg, path_env=str(self.no_ffmpeg))[0], 3)
        for args in ((), (self.case1, "--target", "loud"), (self.case1, "--tolerance", "-1")):
            with self.subTest(args=args):
                self.assertEqual(self.run_meter(*args).returncode, 2)

    def test_text_output_and_nothing_written(self) -> None:
        before = sorted(self.root.rglob("*"))
        result = self.run_meter(self.case1, "--target", "aswg-portable")
        self.assertEqual(result.returncode, 1)
        lines = result.stdout.splitlines()
        self.assertTrue(lines[0].startswith("ERROR ") and lines[1].startswith("  fix: "), lines)
        self.assertIn("integrated -23.0 LUFS, true peak -23.0 dBTP (wave, 48000 Hz, 2 ch, 2.0 s)", result.stdout)
        self.assertEqual(lines[-1], "Summary: 1 errors, 1 of 1 files measured")
        self.assertEqual(sorted(self.root.rglob("*")), before)
        self.assertIn("ASWG-R001 v1.10", self.run_meter("--help").stdout)

    def test_riff_parser_reads_an_extensible_pcm_header(self) -> None:
        spec = importlib.util.spec_from_file_location("loudness_meter", METER)
        meter = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(meter)
        ext = extensible_wav(self.root / "unit-ext.wav", self.case1).read_bytes()
        reader = meter.PcmWav(io.BytesIO(ext))
        self.assertEqual((reader.getnchannels(), reader.getsampwidth(), reader.getframerate()), (2, 3, 48000))
        with wave.open(str(self.case1), "rb") as src:
            self.assertEqual(reader.readframes(5), src.readframes(5))
        data_at = ext.index(b"data")
        streamed = ext[:4] + b"\xff" * 4 + ext[8:data_at + 4] + b"\xff" * 4 + ext[data_at + 8:]
        reader = meter.PcmWav(io.BytesIO(streamed))
        self.assertEqual(len(reader.readframes(96000)), 96000 * 6)
        with self.assertRaises(meter.NotPcm):
            meter.PcmWav(io.BytesIO(extensible_wav(self.root / "unit-float.wav", self.case1, subformat=3).read_bytes()))

    def test_extensible_pcm_wav_reads_where_wave_rejects_it(self) -> None:
        """WAVE_FORMAT_EXTENSIBLE with the PCM SubFormat; wave reads it only from Python 3.12, simulated here."""
        ext = extensible_wav(self.root / "ext24.wav", self.case1)
        flt = extensible_wav(self.root / "ext-float.wav", self.case1, subformat=3)
        code, payload = self.report(ext, flt, path_env=str(self.no_ffmpeg), shim=PY311_WAVE)
        self.assertEqual((code, [e["code"] for e in payload["errors"]]), (3, ["needs-ffmpeg"]))
        self.assertEqual(self.file(payload, "ext24.wav")["decoder"], "wave")
        self.assertAlmostEqual(self.file(payload, "ext24.wav")["integrated_lufs"], -23.0, delta=0.1)

    def test_a_big_endian_host_is_refused_with_exit_2(self) -> None:
        result = self.run_meter(self.case1, shim=BIG_ENDIAN)
        self.assertEqual((result.returncode, result.stdout), (2, ""))
        self.assertIn("big-endian", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    @unittest.skipIf(FFMPEG is None, "ffmpeg not on PATH")  # skip: ffmpeg is optional; the exit-3 case covers its absence
    def test_ffmpeg_output_reads_where_wave_rejects_extensible(self) -> None:
        """ffmpeg writes pcm_s32le as WAVE_FORMAT_EXTENSIBLE; wave reads it only from Python 3.12, simulated here."""
        flt = float_wav(self.root / "float-311.wav", 48000,
                        [10 ** (-23 / 20) * math.sin(2 * math.pi * 997 * i / 48000) for i in range(48000)])
        code, payload = self.report(flt, shim=PY311_WAVE)
        self.assertEqual((code, payload["errors"]), (0, []))
        self.assertAlmostEqual(self.file(payload, "float-311.wav")["integrated_lufs"], -26.01, delta=0.05)

    @unittest.skipIf(FFMPEG is None, "ffmpeg not on PATH")  # skip: ffmpeg is optional; the exit-3 case covers its absence
    def test_ffmpeg_reads_a_relative_name_with_a_colon(self) -> None:
        float_wav(self.root / "boss:2.wav", 48000, [0.1 * math.sin(2 * math.pi * 997 * i / 48000) for i in range(48000)])
        result = self.run_meter("boss:2.wav", "--json", cwd=self.root)
        payload = json.loads(result.stdout)
        self.assertEqual((result.returncode, payload["errors"]), (0, []))
        self.assertEqual((payload["files"][0]["path"], payload["files"][0]["decoder"]), ("boss:2.wav", "ffmpeg"))

    @unittest.skipIf(FFMPEG is None, "ffmpeg not on PATH")  # skip: ffmpeg is optional; the exit-3 case covers its absence
    def test_ffmpeg_decodes_float_wav_and_ogg(self) -> None:
        flt = float_wav(self.root / "float-tone.wav", 48000,
                        [10 ** (-23 / 20) * math.sin(2 * math.pi * 997 * i / 48000) for i in range(48000)])
        ogg = self.root / "case1.ogg"
        subprocess.run([FFMPEG, "-v", "error", "-y", "-i", str(self.case1), "-c:a", "libvorbis", str(ogg)], check=True)
        code, payload = self.report(flt, ogg)
        self.assertEqual(code, 0, payload)
        self.assertAlmostEqual(self.file(payload, "float-tone.wav")["integrated_lufs"], -26.01, delta=0.05)
        self.assertEqual(self.file(payload, "case1.ogg")["decoder"], "ffmpeg")
        self.assertAlmostEqual(self.file(payload, "case1.ogg")["integrated_lufs"], -23.0, delta=0.2)

    @unittest.skipIf(FFMPEG is None, "ffmpeg not on PATH")  # skip: ffmpeg is the independent oracle here, absent on some runners
    def test_agrees_with_ffmpeg_ebur128_on_noise(self) -> None:
        rng = random.Random(1770)
        frames = b"".join(struct.pack("<hh", int(rng.gauss(0, 3000)), int(rng.gauss(0, 1500))) for _ in range(44100 * 3))
        noise = write_wav(self.root / "noise.wav", 44100, 2, 2, frames)
        ours = self.report(noise)[1]["files"][0]
        probe = subprocess.run([FFMPEG, "-hide_banner", "-nostats", "-i", str(noise), "-af", "ebur128=peak=true",
                                "-f", "null", "-"], capture_output=True, text=True).stderr
        summary = probe[probe.rindex("Summary:"):]
        integrated = float(re.search(r"I:\s+(-?[\d.]+) LUFS", summary).group(1))
        peak = float(re.search(r"True peak:\s+Peak:\s+(-?[\d.]+) dBFS", summary).group(1))
        self.assertAlmostEqual(ours["integrated_lufs"], integrated, delta=0.1)
        self.assertAlmostEqual(ours["true_peak_dbtp"], peak, delta=0.3)


if __name__ == "__main__":
    unittest.main()
