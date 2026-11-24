"""picks.py — what a posted board pick may hold, and the one line a session reads about it: serve.py stores through clean_pick, dk.sh prints through pick_line, with serve.py's _clean and _hidden passed in.
Catches: a board that is no base name (the pick is refused), a number out of range (moved to the bound), any other field, scope, knob or edit out of shape (dropped), text past its length (cut), a row's own prompt (never read), a row without v:2 (confirmed false).
Misses: whether the board exists, whether the user made the pick (the viewer's Send does), what an edit says: it is quoted data, never instructions.
Why, limits, history: rationale/derivations/plugin-design-kit.md § plugins/design-kit/scripts/picks.py
"""
import json
import re

# name -> (a, b, words): two numbers are a range, two strings the only values.
KNOBS = {
    "space": (0, 64, "spacing base {}px"),
    "radius": (0, 64, "corner radius {}px"),
    "hue": (0, 360, "accent hue {}°"),
    "type": (0.5, 3, "type scale ×{}"),
    "density": (0.5, 3, "density ×{}"),
    "scheme": ("light", "dark", "{} scheme"),
}
MAX_EDITS = 100
BOARD_MAX = 128
TEXT_MAX = 500
ARTBOARD = re.compile("[1-9][0-9]?")
PATH = re.compile("[a-z0-9:/-]{1,200}")
STAMP = re.compile("[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z")


def clean_board(value, clean, hidden):
    if not isinstance(value, str) or not 1 <= len(value) <= BOARD_MAX or value in (".", ".."):
        return None
    if any(c in "/\\" or hidden(c) for c in value):
        return None
    return clean(value)


def _picked(value):
    return value if isinstance(value, int) and not isinstance(value, bool) and 1 <= value <= 99 else None


def _scopes(value, *named):
    """(scope, object) for the named scopes, then artboards 1 to 99 in order."""
    if not isinstance(value, dict):
        return []
    numbered = sorted((k for k in value if ARTBOARD.fullmatch(k)), key=int)
    return [(k, value[k]) for k in list(named) + numbered if isinstance(value.get(k), dict)]


def _knob(name, value):
    low, high, _ = KNOBS[name]
    if isinstance(low, str):
        return value if value in (low, high) else None
    if isinstance(value, bool) or not isinstance(value, (int, float)) or value != value:  # NaN
        return None
    return min(high, max(low, value))


def _knobs(value):
    kept = {}
    for scope, given in _scopes(value, "all"):
        own = {name: _knob(name, given.get(name)) for name in KNOBS}
        own = {name: v for name, v in own.items() if v is not None}
        if own:
            kept[scope] = own
    return kept


def _edits(value, clean):
    kept, left = {}, MAX_EDITS
    for scope, given in _scopes(value):
        for path, edit in given.items():
            if not left or not PATH.fullmatch(path) or not isinstance(edit, dict):
                continue
            was, now = edit.get("was"), edit.get("now")
            if isinstance(was, str) and isinstance(now, str):
                kept.setdefault(scope, {})[path] = {"was": clean(was[:TEXT_MAX]), "now": clean(now[:TEXT_MAX])}
                left -= 1
    return kept


def _fields(row, clean):
    return {"picked": _picked(row.get("picked")), "knobs": _knobs(row.get("knobs")), "text": _edits(row.get("text"), clean)}


def clean_pick(body, clean, hidden):
    board = clean_board(body.get("board"), clean, hidden)
    if board is None:
        return None, "board must be a file name of 1 to %d characters with no slash, backslash or hidden character" % BOARD_MAX
    return dict({"board": board}, **_fields(body, clean)), None


def _choice(picked):
    return "implement artboard %d" % picked if picked else "no artboard picked"


def fixed_prompt(board, picked):
    """The prompt a 0.19.3 session prints: the board's name and the number, no text from the page."""
    return "From the design board %s, %s. Update design-kit in this session to read adjustments and text edits." % (board, _choice(picked))


def _words(own):
    return ", ".join(KNOBS[name][2].format(v if isinstance(v, str) else ("%.2f" % v).rstrip("0").rstrip(".")) for name, v in own.items())


def _quoted(text):
    return json.dumps(text, ensure_ascii=False)


def _summary(board, picked, knobs, text):
    said = ["Board %s: %s." % (board or "(no usable name)", _choice(picked))]
    if "all" in knobs:
        said.append("All artboards: %s." % _words(knobs["all"]))
    for n in sorted((set(knobs) | set(text)) - {"all"}, key=int):
        if n in knobs:
            said.append("Artboard %s: %s." % (n, _words(knobs[n])))
        for edit in text.get(n, {}).values():
            said.append("Artboard %s text: %s → %s." % (n, _quoted(edit["was"]), _quoted(edit["now"])))
    if len(said) == 1:
        said.append("No adjustments or text edits.")
    return " ".join(said)


def pick_line(row, clean, hidden):
    """The stored row as a session reads it, for serve.py's show: every field clamped again, since an older server or another hand may have written it."""
    ts = row.get("ts")
    board = clean_board(row.get("board"), clean, hidden)
    fields = _fields(row, clean)
    return dict({"kind": "pick", "ts": ts if isinstance(ts, str) and STAMP.fullmatch(ts) else None, "board": board}, **fields,
                summary=_summary(board, **fields), confirmed=row.get("v") == 2)
