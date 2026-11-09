# gamedev: derivations (2026-11-09)

Standing: `recorded`. No gate reads this file. Every upstream fact below was fetched on 2026-11-09
unless it says otherwise.

## plugins/gamedev/scripts/check_steam_build.py

Copied from gamedev-skills/awesome-gamedev-agent-skills@184b72b (Apache-2.0) in gamedev 0.1.0; its
NOTICE line lists the changes. Two errors were added on 2026-11-09 (gamedev 0.3.0, roadmap row GD8):

- **`steam-appid-txt-shipped`.** A file named `steam_appid.txt` (any letter case) among a depot's
  uploads, after `FileExclusion`. Verified at https://partner.steamgames.com/doc/sdk/api: "You
  should not ship this with your builds", and for `SteamAPI_RestartAppIfNecessary`, "if a
  steam_appid.txt file is present then this will return false regardless … Make sure to remove the
  steam_appid.txt file when uploading the game to your Steam depot!" The message adds "it holds 480"
  when the file's text is exactly `480`.
- **`appid-spacewar`.** `AppID` 480 in the AppBuild script. Verified at
  https://partner.steamgames.com/doc/sdk/api/example: "the example game's AppID is 480".

Silent on purpose: a `steam_appid.txt` dropped by `FileExclusion "*steam_appid.txt"`, one beside the
build scripts, `steam_appid.txt.example`, and AppIDs 4800 and 1480. Each is a harness case.

Limits: a depot ID that belongs to Spacewar is not checked (its depot IDs were not verified). A
`steam_appid.txt` that the game writes at run time is outside any build script.

## plugins/gamedev/scripts/check_itch_html5.py

Added 2026-11-09 (gamedev 0.3.0, GD8). Until then the itch-release skill stated the HTML5 ZIP limits
as **recorded**: itch.io enforced them at upload or play time, after the build had shipped.

Limits, verified at https://itch.io/docs/creators/html5 ("ZIP file requirements"):

- "The ZIP file must contain a file called index.html". The page does not say it must be at the
  root. The root rule comes from the roadmap row and the skill's own recorded rule (2026-10-26). A
  nested `index.html` is still reported as an error, and the message names where it is.
- "not … more than 1,000 individual files after extraction"; "maximum length of a file name
  including path should not be greater than 240 characters"; "all the extracted content should not
  be greater than 500MB"; "any single extracted file should not be greater than 200MB"; "case
  sensitive and should be encoded as UTF-8". It also says only ZIP works: "We do not support any
  other archive types".
- The page does not say whether MB means 10^6 or 2^20 bytes. The checker uses 10^6, the stricter
  reading. A game between 500,000,000 and 524,288,000 bytes could be a false error.

How it reads: only `zipfile`'s central directory, so a ZIP bomb costs nothing. A name stored
without the UTF-8 flag is re-encoded to its raw bytes (CP437 round-trips) and decoded as UTF-8, so
a UTF-8 name stored without the flag passes. A legacy code-page name fails.

Silent neighbours in the harness: exactly 1,000 files, exactly 500,000,000 bytes with two files of
exactly 200,000,000, a 240-character path, and an unflagged UTF-8 name.

Not checked, and named in the skill: absolute `/` paths and wrong-case references inside the
game's code, non-HTTPS requests, and the page's Kind and embed settings. Also a backslash in an
entry name. The ZIP spec forbids it (PKWARE APPNOTE 4.4.17, verified), but itch.io's page does not
list it. Which Windows tools write one is unverified. It is left as a follow-up.

## plugins/gamedev/scripts/loudness_meter.py

Added 2026-11-09 (gamedev 0.3.0, GD8). Until then `game-platform-floors` said "nothing here meters
audio", and the ASWG targets were **agent-graded** against a meter the user had to find.

**Algorithm**, verified against ITU-R BS.1770-5 (11/2023),
https://www.itu.int/dms_pubrec/itu-r/rec/bs/R-REC-BS.1770-5-202311-I!!PDF-E.pdf:

- K-weighting is the two-stage pre-filter of Tables 1 and 2. Those coefficients are for 48 kHz
  only, and the Recommendation asks other rates for "the same frequency response". The script
  builds both stages from analogue-prototype parameters: shelf f0 1681.974 Hz, gain 3.99984 dB,
  Q 0.70718; high-pass f0 38.1355 Hz, Q 0.50033. These are the parameters libebur128 uses, quoted
  from memory and not fetched. They are verified by computation instead: at 48 kHz they reproduce
  every Table 1 and Table 2 coefficient to 15 significant digits.
- Gating uses 400 ms blocks with 75% overlap, built from 100 ms sub-blocks. The absolute gate is
  −70 LKFS, the relative gate −10 LU. L = −0.691 + 10·log10(Σ G_i·z_i). Weights follow Table 3:
  L, R and C 1.0, Ls and Rs 1.41, LFE left out. Layouts other than 1, 2, 5 and 6 channels exit 2,
  because Annex 3's position weights would need a channel map the WAV header may not carry. An
  incomplete last block is dropped, as the text says.
- True peak uses Annex 2's order-48, 4-phase FIR at 4x. The reported value is the larger of that
  and the sample peak, because the continuous waveform passes through every sample. The 12.04 dB
  attenuation is skipped in the float path. For ffmpeg-decoded input it is applied as
  `volume=0.25`, so an OGG overshoot above 0 dBFS survives the int32 PCM pipe.
- Speed: windows that cannot beat the running peak are skipped, by the bound |y| ≤ 2.02 · max|x|
  (2.02 is the largest phase's sum of |taps|). Measured on this machine (Python 3.14.4): 5 minutes
  of stereo 48 kHz pink noise in 5.3 s. A steady tone is the worst case, about 4.5 s per stereo
  minute (EBU case 5), because nearly every window stays within reach of the peak.

**Checked against EBU Tech 3341 V4 (November 2023)**, https://tech.ebu.ch/docs/tech/tech3341.pdf,
Table 1:

- Cases 1–6: −23.0 or −33.0 ±0.1 LUFS. Measured −23.0, −33.0, −23.0 (case 3), −23.01 (case 4),
  −22.98 (case 5) and −23.0 (case 6, 5.0).
- Cases 15–19: −6.0 / +3.0 dBTP, tolerance +0.2/−0.4. Measured −6.0, −6.0, −6.3, −6.0 and +3.0.
  Case 17 reads −6.3, inside tolerance. ffmpeg reads −6.0 there, because its resampler places more
  points.
- Not run: cases 7–8 (programme files not fetched), 9–14 (short-term and momentary, not
  implemented), and 20–23 (the 192 kHz synthesis was not built).
- Cross-checked with ffmpeg 8.0.1's `ebur128=peak=true`. Integrated loudness and true peak agreed
  to its 0.1 display precision on:
  - EBU cases 2–6;
  - a 44.1 kHz tone;
  - 60 s of pink noise at two levels, and 5 minutes at a third;
  - a 5.1 Vorbis file, with the LFE left out;
  - a mono 0 dBFS 997 Hz tone, read as −3.0 (BS.1770 states −3.01);
  - the half-length variants of cases 3–5 (integrated only).

  The harness repeats the comparison on 3 s of 44.1 kHz Gaussian noise where ffmpeg is present.
  The half-length variants are not EBU cases, and the harness does not use them.

**Targets.** These are verified:

- ASWG-R001 v1.10. Home −24 ±2 LKFS, portable −18 ±2 LKFS, true peak not above −1 dBTP. Measure
  the whole mix for at least 30 minutes, in stereo and in surround. Read from the copy at
  http://gameaudiopodcast.com/ASWG-R001.pdf, a third-party host; Sony does not publish it.
- Spotify. "We adjust tracks to -14 dB LUFS" and "Keep it below -1dB TP", from
  https://support.spotify.com/us/artists/article/loudness-normalization/. This is a music-release
  figure, named in `--help` and not shipped as a preset.

Unverified, and left out: an Apple Music −16 LUFS figure. Apple's Digital Masters PDF
(https://www.apple.com/apple-music/apple-digital-masters/docs/apple-digital-masters.pdf) describes
Sound Check but states no LKFS number.

**Decoding.** Python's `wave` module reads integer PCM at 8, 16, 24 and 32 bits, and
WAVE_FORMAT_EXTENSIBLE from Python 3.12. It refuses IEEE float (format 3). Those files, and OGG, go
through `ffmpeg -f wav -c:a pcm_s32le` on a pipe. `wave` reads that stream although its size
fields are 0xFFFFFFFF, checked with ffmpeg 8.0.1. Without ffmpeg on PATH the script exits 3 and
says why.

Not measured: momentary, short-term and loudness range (ASWG's third descriptor is LRA, per EBU
Tech 3342). The meter also cannot judge whether a capture is representative. That stays
**agent-graded** in the skill. Big-endian hosts take the `byteswap` path, which no test covers.
