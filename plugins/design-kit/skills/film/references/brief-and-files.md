# Brief and the four files `film.py` reads

## The brief

Fill what the user gave; decide the rest and log each choice with its reason in `brief.txt`.

| Field | Blank means |
|---|---|
| Type: product demo / launch / explainer | read it from the ask |
| Product URL or topic | ask — there is no film without one |
| Who is watching, and what they do in the last second | infer from the product; the last second shows that action |
| Length and format (`20 s 16:9`, `30 s 16:9 + 9:16`) | 20 s, 16:9 |
| Frame rate | 60 for a UI demo, 30 otherwise |
| Brand: logo, colours, fonts | taken from the product site |
| Facts source: URL or file | the product site; every on-screen line comes from it |
| Reference video: a local MP4 | no breakdown |
| Music: a local audio file | synthesized in code (`film.py music`) — say so; some viewers reject synthesized scores, so a supplied track is the user's call |
| Sound: music + sfx / voice + music + sfx / silent | music + sfx. Voice needs a TTS tool with its key in an environment variable; without one, stop and say so |
| Renderer: HyperFrames / Remotion | HyperFrames (Node 22+; `npx hyperframes init` in the workspace) |
| Run mode: stop at every ⏸ / run to the end | stop at every ⏸ |

A third-party TTS, music or SFX service is integration code: verify its current API docs before
calling it (the api-design plugin's `api-docs-first` rule), and name a credit-spending call
before making it.

## `facts.json`

```json
{"facts": [{"id": "f1", "text": "Reporting in 15 minutes",
            "original": "Teams cut weekly reporting from 4 hours to 15 minutes.",
            "url": "https://example.com/customers"}]}
```

`original` is the source sentence verbatim; `text` is the on-screen phrasing. `film.py check`
fails a line with no `fact`, an unknown id, or a number its fact's `original` + `text` lacks.

## `timing.json`

```json
{"fps": 60, "duration_s": 20, "sound": "music",
 "formats": [{"name": "16x9", "width": 1920, "height": 1080, "file": "film-16x9.mp4"},
             {"name": "9x16", "width": 1080, "height": 1920, "file": "film-9x16.mp4"}],
 "music": {"source": "synth", "bpm": 120, "beat_times": [0.0, 0.5, 1.0]},
 "scenes": [{"id": "hook", "start": 0.0, "cut": "hard"}, {"id": "proof", "start": 4.0, "cut": "hard"}],
 "actions": [{"id": "click-export", "t": 6.5}],
 "text": [{"text": "Reporting in 15 minutes", "fact": "f1", "start": 0.2, "end": 2.0,
           "format": "16x9", "box": {"x": 160, "y": 420, "w": 900, "h": 140}}]}
```

`music` is written by `film.py music` or `film.py beats --write`; never type beat times by hand.
`sound: "silent"` turns the sync checks off. A `box` (pixels in that format) turns on the
bottom-8% and overlap checks for that line; a line without one is checked for facts and hold only.
Every component reads its times from here — a duration typed into a component is a second
source of truth.

## `style.json`

```json
{"colors": {"ink": "#101014", "paper": "#f4f1ea", "accent": "#1f4fe0"},
 "text_pairs": [["ink", "paper"], ["paper", "accent"]],
 "easing": {"in": "cubic-bezier(0.22, 1, 0.36, 1)", "out": "cubic-bezier(0.4, 0, 1, 1)"},
 "handoffs": {"hook→proof": {"x": 960, "y": 540}}}
```

`text_pairs` lists every foreground/background pair text is set in; `check` computes each ratio.
More than six colours fails the style lock.

## `ledger.txt`

`film.py check --ledger ledger.txt --round N` appends one block per round. Add the review round's
severity counts and the loudness before/after line by hand, so every round shows before and
after numbers.
