#!/usr/bin/env python3
"""Measure integrated loudness (ITU-R BS.1770 K-weighted, gated, LUFS) and true peak (dBTP) of WAV and OGG files; with --target, exit 1 off target.
Integer PCM WAV, WAVE_FORMAT_EXTENSIBLE included, is parsed here; OGG, float WAV and other encodings are decoded by ffmpeg when it is on PATH, else exit 3.
Does not measure momentary, short-term or loudness range, weight layouts other than mono, stereo, 5.0 and 5.1, run on a big-endian host (exit 2), or judge whether a capture is representative."""
# Why, limits, history: rationale/derivations/plugin-gamedev.md § plugins/gamedev/scripts/loudness_meter.py

from __future__ import annotations

import argparse
import json
import math
import shutil
import struct
import subprocess
import sys
import tempfile
from array import array
from operator import mul
from pathlib import Path

TOOL = "loudness_meter"
SCHEMA = 1

# K-weighting as analogue prototypes; at 48 kHz they give BS.1770-5 Tables 1 and 2 to 15 digits.
SHELF_F0, SHELF_GAIN_DB, SHELF_Q, SHELF_VB_EXP = 1681.974450955533, 3.999843853973347, 0.7071752369554196, 0.4996667741545416
HIGHPASS_F0, HIGHPASS_Q = 38.13547087602444, 0.5003270373238773

# BS.1770-5 Annex 2: the order-48, 4-phase FIR interpolator, 4x oversampling.
TRUE_PEAK_PHASES = (
    (0.0017089843750, 0.0109863281250, -0.0196533203125, 0.0332031250000, -0.0594482421875, 0.1373291015625,
     0.9721679687500, -0.1022949218750, 0.0476074218750, -0.0266113281250, 0.0148925781250, -0.0083007812500),
    (-0.0291748046875, 0.0292968750000, -0.0517578125000, 0.0891113281250, -0.1665039062500, 0.4650878906250,
     0.7797851562500, -0.2003173828125, 0.1015625000000, -0.0582275390625, 0.0330810546875, -0.0189208984375),
    (-0.0189208984375, 0.0330810546875, -0.0582275390625, 0.1015625000000, -0.2003173828125, 0.7797851562500,
     0.4650878906250, -0.1665039062500, 0.0891113281250, -0.0517578125000, 0.0292968750000, -0.0291748046875),
    (-0.0083007812500, 0.0148925781250, -0.0266113281250, 0.0476074218750, -0.1022949218750, 0.9721679687500,
     0.1373291015625, -0.0594482421875, 0.0332031250000, -0.0196533203125, 0.0109863281250, 0.0017089843750),
)
TAPS = len(TRUE_PEAK_PHASES[0])
REVERSED_PHASES = tuple(tuple(reversed(p)) for p in TRUE_PEAK_PHASES)
FIR_GAIN = max(sum(abs(t) for t in p) for p in TRUE_PEAK_PHASES)
dot = getattr(math, "sumprod", None) or (lambda a, b: sum(map(mul, a, b)))

# BS.1770-5 Table 3 in WAV channel order; the LFE (5.1 index 3) is left out.
CHANNEL_WEIGHTS = {1: (1.0,), 2: (1.0, 1.0), 5: (1.0, 1.0, 1.0, 1.41, 1.41), 6: (1.0, 1.0, 1.0, 0.0, 1.41, 1.41)}
ABSOLUTE_GATE = -70.0
RELATIVE_GATE = -10.0

PRESETS = {
    "aswg-home": (-24.0, 2.0, -1.0, "ASWG-R001 v1.10 home-based platforms"),
    "aswg-portable": (-18.0, 2.0, -1.0, "ASWG-R001 v1.10 portable platforms"),
}
U8_TO_S8 = bytes((b - 128) & 0xFF for b in range(256))
WAVE_FORMAT_PCM, WAVE_FORMAT_EXTENSIBLE = 0x0001, 0xFFFE
PCM_GUID_TAIL = b"\x00\x00\x00\x00\x10\x00\x80\x00\x00\xaa\x00\x38\x9b\x71"  # KSDATAFORMAT_SUBTYPE_PCM after its format tag
STREAMED = 0xFFFFFFFF  # the size ffmpeg writes when it pipes a WAV
FFMPEG_SCALE = 0.25  # decode 12.04 dB down (BS.1770 Annex 2's headroom) so overs above 0 dBFS survive int32


class Unreadable(Exception):
    code = "unreadable"


class ChannelsUnsupported(Unreadable):
    code = "channels-unsupported"


class NeedsFfmpeg(Exception):
    pass


class NotPcm(Exception):
    """A RIFF/WAVE header this parser cannot read as integer PCM; ffmpeg may still decode it."""


class PcmWav:
    """Integer PCM from a RIFF/WAVE stream, WAVE_FORMAT_EXTENSIBLE included; the reader API measure() uses."""

    def __init__(self, stream) -> None:
        self.stream = stream
        head = stream.read(12)
        if len(head) < 12 or head[:4] != b"RIFF" or head[8:12] != b"WAVE":
            raise NotPcm("not a RIFF/WAVE stream")
        fmt = None
        while True:
            chunk = stream.read(8)
            if len(chunk) < 8:
                raise NotPcm("no data chunk")
            size = struct.unpack("<I", chunk[4:])[0]
            if chunk[:4] == b"data":
                break
            body = self.take(size + (size & 1))
            if len(body) < size:
                raise NotPcm(f"the {chunk[:4].decode('latin-1')!r} chunk is cut short")
            if chunk[:4] == b"fmt ":
                fmt = body[:size]
        if fmt is None:
            raise NotPcm("no fmt chunk before the data chunk")
        if len(fmt) < 16:
            raise NotPcm("fmt chunk is shorter than 16 bytes")
        tag, self.channels, self.rate, _, _, bits = struct.unpack_from("<HHIIHH", fmt)
        if tag == WAVE_FORMAT_EXTENSIBLE:
            if len(fmt) < 40:
                raise NotPcm("WAVE_FORMAT_EXTENSIBLE fmt chunk is shorter than 40 bytes")
            tag = struct.unpack_from("<H", fmt, 24)[0] if fmt[26:40] == PCM_GUID_TAIL else None
        if tag != WAVE_FORMAT_PCM:
            raise NotPcm("not integer PCM")
        self.width = (bits + 7) // 8
        if not self.width or not self.channels:
            raise NotPcm("bad sample width or channel count")
        self.remaining = None if size == STREAMED else size

    def take(self, count: int) -> bytes:
        parts = []
        while count > 0:
            part = self.stream.read(min(count, 1 << 16))
            if not part:
                break
            parts.append(part)
            count -= len(part)
        return b"".join(parts)

    def getnchannels(self) -> int:
        return self.channels

    def getsampwidth(self) -> int:
        return self.width

    def getframerate(self) -> int:
        return self.rate

    def readframes(self, frames: int) -> bytes:
        count = frames * self.width * self.channels
        if self.remaining is not None:
            count = min(count, self.remaining)
        data = self.take(count)
        if self.remaining is not None:
            self.remaining -= len(data)
        return data

    def close(self) -> None:
        self.stream.close()


def biquads(rate: int) -> tuple[float, ...]:
    k = math.tan(math.pi * SHELF_F0 / rate)
    vh = 10 ** (SHELF_GAIN_DB / 20)
    vb = vh ** SHELF_VB_EXP
    a0 = 1 + k / SHELF_Q + k * k
    shelf = ((vh + vb * k / SHELF_Q + k * k) / a0, 2 * (k * k - vh) / a0, (vh - vb * k / SHELF_Q + k * k) / a0,
             2 * (k * k - 1) / a0, (1 - k / SHELF_Q + k * k) / a0)
    k = math.tan(math.pi * HIGHPASS_F0 / rate)
    a0 = 1 + k / HIGHPASS_Q + k * k
    return shelf + (2 * (k * k - 1) / a0, (1 - k / HIGHPASS_Q + k * k) / a0)


def kweighted_energy(samples, coeffs: tuple[float, ...], state: list[float]) -> float:
    b0, b1, b2, a1, a2, h1, h2 = coeffs
    z1, z2, u1, u2 = state
    total = 0.0
    for x in samples:
        y = b0 * x + z1
        z1 = b1 * x - a1 * y + z2
        z2 = b2 * x - a2 * y
        w = y + u1
        u1 = -2.0 * y - h1 * w + u2
        u2 = y - h2 * w
        total += w * w
    state[:] = (z1, z2, u1, u2)
    return total


def true_peak(samples, history: list, peak: float) -> float:
    """Raise peak to the largest |sample| or 4x-interpolated value; only windows that could beat it are filtered."""
    extended = history + list(samples)
    if samples:
        peak = max(peak, max(map(abs, samples)))
    threshold = peak / FIR_GAIN
    reach = bytearray(len(extended) + TAPS)
    span = b"\x01" * TAPS
    for i, v in enumerate(map(abs, extended)):
        if v > threshold:
            reach[i:i + TAPS] = span
    for n in range(TAPS - 1, len(extended)):
        if reach[n]:
            window = extended[n - TAPS + 1:n + 1]
            for taps in REVERSED_PHASES:
                value = abs(dot(taps, window))
                if value > peak:
                    peak = value
    history[:] = extended[-(TAPS - 1):]
    return peak


def split_channels(data: bytes, width: int, channels: int) -> list:
    if width == 1:
        values = array("b", data.translate(U8_TO_S8))
    elif width == 2:
        values = array("h", data)
    elif width == 3:
        wide = bytearray(len(data) // 3 * 4)
        wide[1::4], wide[2::4], wide[3::4] = data[0::3], data[1::3], data[2::3]
        values = array("i", bytes(wide))
    elif width == 4:
        values = array("i", data)
    else:
        raise Unreadable(f"{width * 8}-bit samples are not supported")
    return [values[c::channels] for c in range(channels)]


def ffmpeg_decode(path: Path):
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        raise NeedsFfmpeg("ffmpeg is not on PATH")
    log = tempfile.TemporaryFile()
    process = subprocess.Popen(
        [ffmpeg, "-nostdin", "-v", "error", "-i", str(path.resolve()), "-map", "0:a:0", "-af", f"volume={FFMPEG_SCALE}",
         "-c:a", "pcm_s32le", "-f", "wav", "-"],
        stdout=subprocess.PIPE, stderr=log,
    )
    process.log = log
    return process


def ffmpeg_error(process) -> str:
    process.log.seek(0)
    lines = process.log.read().decode("utf-8", "replace").strip().splitlines()
    process.log.close()
    return lines[-1] if lines else f"exit {process.returncode}"


def open_source(path: Path):
    """Return (PcmWav reader, full-scale value, decoder name, ffmpeg process or None)."""
    try:
        with open(path, "rb") as f:
            head = f.read(12)
    except OSError as exc:
        raise Unreadable(f"cannot read: {exc.strerror or exc}") from exc
    if head[:4] == b"RIFF" and head[8:12] == b"WAVE":
        source = open(path, "rb")
        try:
            reader = PcmWav(source)
            width = reader.getsampwidth()
            return reader, float(1 << (31 if width >= 3 else width * 8 - 1)), "wave", None
        except NotPcm as exc:
            source.close()
            if shutil.which("ffmpeg") is None:
                raise NeedsFfmpeg(f"this WAV cannot be read here ({exc}); ffmpeg, not on PATH, decodes float"
                                  " and other encodings") from exc
    elif head[:4] == b"OggS":
        if shutil.which("ffmpeg") is None:
            raise NeedsFfmpeg("OGG is decoded by ffmpeg, which is not on PATH")
    elif shutil.which("ffmpeg") is None:
        raise Unreadable("not a WAV (RIFF/WAVE) or OGG file")
    process = ffmpeg_decode(path)
    try:
        reader = PcmWav(process.stdout)
    except NotPcm as exc:
        process.kill()
        process.wait()
        raise Unreadable(f"ffmpeg could not decode it: {ffmpeg_error(process)}") from exc
    return reader, float(1 << 31) * FFMPEG_SCALE, "ffmpeg", process


def loudness(power: float) -> float:
    return -0.691 + 10 * math.log10(power) if power > 0 else float("-inf")


def gated_loudness(powers: list[float]) -> tuple[float | None, str]:
    above_absolute = [p for p in powers if loudness(p) > ABSOLUTE_GATE]
    if not powers:
        return None, "shorter than one 400 ms gating block"
    if not above_absolute:
        return None, "every 400 ms block is below the -70 LUFS absolute gate"
    relative = loudness(sum(above_absolute) / len(above_absolute)) + RELATIVE_GATE
    kept = [p for p in above_absolute if loudness(p) > relative]
    return loudness(sum(kept) / len(kept)), ""


def measure(path: Path) -> dict:
    reader, full_scale, decoder, process = open_source(path)
    completed = False
    try:
        channels, width, rate = reader.getnchannels(), reader.getsampwidth(), reader.getframerate()
        weights = CHANNEL_WEIGHTS.get(channels)
        if weights is None:
            raise ChannelsUnsupported(f"{channels} channels: only mono, stereo, 5.0 and 5.1 have BS.1770 Table 3 weights here")
        if rate < 8000:
            raise Unreadable(f"sample rate {rate} Hz is below 8 kHz")
        coeffs, step = biquads(rate), max(1, round(rate * 0.1))
        states = [[0.0, 0.0, 0.0, 0.0] for _ in range(channels)]
        histories = [[0] * (TAPS - 1) for _ in range(channels)]
        peaks = [0.0] * channels
        sub_blocks: list[list[float]] = [[] for _ in range(channels)]
        frames = 0
        while True:
            data = reader.readframes(step)
            if not data:
                break
            count = len(data) // (width * channels)
            frames += count
            for c, samples in enumerate(split_channels(data[:count * width * channels], width, channels)):
                peaks[c] = true_peak(samples, histories[c], peaks[c])
                if count == step and weights[c]:
                    sub_blocks[c].append(kweighted_energy(samples, coeffs, states[c]))
            if count < step:
                break
        for c in range(channels):
            peaks[c] = true_peak([0] * (TAPS - 1), histories[c], peaks[c])
        completed = True
    except ValueError as exc:
        raise Unreadable(f"decoding stopped: {exc}") from exc
    finally:
        reader.close()
        if process is not None:
            if not completed:
                process.kill()
            process.stdout.close()
            if process.wait() != 0 and completed:
                raise Unreadable(f"ffmpeg failed: {ffmpeg_error(process)}")
            process.log.close()
    block_frames = 4 * step * full_scale * full_scale
    counted = [c for c in range(channels) if weights[c]]
    powers = [sum(weights[c] * sum(sub_blocks[c][j:j + 4]) for c in counted) / block_frames
              for j in range(len(sub_blocks[counted[0]]) - 3)]
    integrated, note = gated_loudness(powers)
    peak = max(peaks) / full_scale
    return {
        "path": str(path), "decoder": decoder, "sample_rate": rate, "channels": channels,
        "seconds": round(frames / rate, 3),
        "integrated_lufs": None if integrated is None else round(integrated, 2), "integrated_note": note,
        "true_peak_dbtp": round(20 * math.log10(peak), 2) if peak > 0 else None,
    }


def parse_target(value: str) -> tuple[float, float | None, float | None, str]:
    if value in PRESETS:
        return PRESETS[value][:3] + (value,)
    try:
        return float(value), None, None, f"{float(value):g} LUFS"
    except ValueError:
        raise argparse.ArgumentTypeError(f"use a number in LUFS or one of: {', '.join(PRESETS)}") from None


def build_parser() -> argparse.ArgumentParser:
    presets = "\n".join(f"  {name:<14} {t:g} LUFS ±{tol:g} LU, true peak ≤ {tp:g} dBTP ({src})"
                        for name, (t, tol, tp, src) in PRESETS.items())
    parser = argparse.ArgumentParser(
        prog="loudness_meter.py",
        description="Measure integrated loudness (LUFS) and true peak (dBTP) per ITU-R BS.1770-5, and hold them to a target. Read-only.",
        epilog=(
            "example:\n"
            "  python3 loudness_meter.py capture.wav --target aswg-home\n"
            "  python3 loudness_meter.py music/*.ogg --target -20 --tolerance 1 --max-true-peak -1 --json\n\n"
            f"presets:\n{presets}\n"
            "  ASWG-R001: measure the whole mix, not stems, over at least 30 minutes of representative play.\n"
            "  -14 LUFS is Spotify's music normalisation level, not a game mix target.\n\n"
            "errors:\n"
            "  loudness-off-target, true-peak-over (exit 1); unreadable, channels-unsupported (exit 2);\n"
            "  needs-ffmpeg (exit 3)\n\n"
            "exit codes: 0 measured (and within every limit given), 1 a file broke a limit,\n"
            "            2 bad arguments, a big-endian host, or a file that could not be measured,\n"
            "            3 a file needs ffmpeg (OGG, float WAV) and ffmpeg is not on PATH; the highest code wins"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("files", nargs="+", type=Path, metavar="FILE", help="WAV or OGG files")
    parser.add_argument("--target", type=parse_target, metavar="PRESET|LUFS",
                        help=f"integrated loudness target: {', '.join(PRESETS)}, or a number")
    parser.add_argument("--tolerance", type=float, metavar="LU",
                        help="allowed distance from --target (default: the preset's, else 1 LU)")
    parser.add_argument("--max-true-peak", type=float, metavar="DBTP",
                        help="fail when the true peak is above this (default: the preset's, else none)")
    parser.add_argument("--json", action="store_true", help="print one JSON object instead of text")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    target = args.target
    tolerance = args.tolerance if args.tolerance is not None else (target[1] if target and target[1] is not None else 1.0)
    ceiling = args.max_true_peak if args.max_true_peak is not None else (target[2] if target else None)
    if tolerance < 0:
        parser.error("--tolerance must be 0 or more")
    if sys.byteorder != "little":
        print(f"{TOOL}: this host is big-endian; samples are decoded as little-endian here, so nothing is measured",
              file=sys.stderr)
        return 2
    reports, errors, exit_code = [], [], 0

    def fail(code: str, path: Path, message: str, fix: str, level: int) -> None:
        nonlocal exit_code
        errors.append({"code": code, "file": str(path), "message": message, "fix": fix})
        exit_code = max(exit_code, level)

    for path in args.files:
        try:
            report = measure(path)
        except NeedsFfmpeg as exc:
            fail("needs-ffmpeg", path, str(exc), "Install ffmpeg, or export the file as 16- or 24-bit integer PCM WAV.", 3)
            continue
        except Unreadable as exc:
            fail(exc.code, path, str(exc), "Export a mono, stereo, 5.0 or 5.1 WAV or OGG and measure that.", 2)
            continue
        except Exception as exc:  # a malformed file must never exit 1, which reads as a measured failure
            fail("unreadable", path, f"malformed audio ({type(exc).__name__}: {exc})",
                 "Re-export the file and measure it again.", 2)
            continue
        reports.append(report)
        value = report["integrated_lufs"]
        if target is not None:
            if value is None:
                fail("loudness-off-target", path, f"no integrated loudness ({report['integrated_note']}), so it cannot meet"
                     f" the {target[3]} target", "Measure a longer capture of the whole mix.", 1)
            elif abs(value - target[0]) > tolerance:
                diff = value - target[0]
                fail("loudness-off-target", path,
                     f"integrated {value:.1f} LUFS is {abs(diff):.1f} LU {'above' if diff > 0 else 'below'} the {target[3]}"
                     f" target {target[0]:g} ±{tolerance:g} LUFS",
                     f"{'Lower' if diff > 0 else 'Raise'} the whole mix by about {abs(diff):.1f} dB, then measure again.", 1)
        peak = report["true_peak_dbtp"]
        if ceiling is not None and peak is not None and peak > ceiling:
            fail("true-peak-over", path, f"true peak {peak:+.1f} dBTP is above the {ceiling:g} dBTP ceiling",
                 "Lower the peaks with a true-peak limiter, or lower the mix, then measure again.", 1)

    if args.json:
        print(json.dumps({
            "tool": TOOL, "schema": SCHEMA,
            "target": None if target is None else {"name": target[3], "lufs": target[0], "tolerance_lu": tolerance},
            "max_true_peak_dbtp": ceiling, "files": reports, "error_count": len(errors), "errors": errors,
        }, indent=2))
    else:
        lines = []
        for error in errors:
            lines += [f"ERROR {error['file']}: {error['message']}", f"  fix: {error['fix']}"]
        if reports:
            lines.append("Measured:")
            for r in reports:
                lufs = f"{r['integrated_lufs']:.1f} LUFS" if r["integrated_lufs"] is not None else f"- ({r['integrated_note']})"
                peak = f"{r['true_peak_dbtp']:+.1f} dBTP" if r["true_peak_dbtp"] is not None else "-inf dBTP"
                lines.append(f"  {r['path']}: integrated {lufs}, true peak {peak}"
                             f" ({r['decoder']}, {r['sample_rate']} Hz, {r['channels']} ch, {r['seconds']:.1f} s)")
        lines.append(f"Summary: {len(errors)} errors, {len(reports)} of {len(args.files)} files measured")
        print("\n".join(lines))
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
