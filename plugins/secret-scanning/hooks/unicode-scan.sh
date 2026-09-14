#!/bin/bash
# Absolute-path shebang not `/usr/bin/env bash`: the fail-open guarantee must hold
# even under a stripped PATH where `env bash` exits 127.
#
# PostToolUse scan for INVISIBLE characters in text the model just wrote or read.
# Warns — never blocks — naming the codepoint and the line, on:
#
#   U+200B-U+200D  zero-width space / non-joiner / joiner
#   U+2060         word joiner
#   U+FEFF         zero-width no-break space (BOM), mid-file only
#   U+202A-U+202E  bidirectional overrides (the "Trojan Source" class, CVE-2021-42574)
#   U+2066-U+2069  bidi isolates
#   U+00AD         soft hyphen
#   U+E0000-U+E007F  Unicode tag block — the "invisible instruction" carrier
#
# WHY A SCRIPT AND NOT PROSE. The model cannot see these characters. They do not render,
# they survive copy-paste, and in the bidi class they make source code display in an
# order different from the order it executes — a reviewer reads one program and the
# compiler reads another. No amount of instruction helps with a byte that is not shown;
# only a scanner reports it. This is the one rule in this plugin whose subject is
# invisible by definition.
#
# WHY PostToolUse AND WARN, NOT PreToolUse AND DENY. Two reasons, both measured rather
# than assumed: legitimate zero-width joiners appear in emoji sequences and in Arabic,
# Persian and Indic text, so a deny would break writing those languages; and the
# interesting case is usually a file being READ — content arriving from outside the
# session, where blocking the read helps nobody and knowing what is in it does.
#
# WHAT IT DOES NOT CATCH, stated because the README tiers it:
#   - Homoglyphs (Cyrillic а in an ASCII word). Those are visible, just not distinct;
#     a different check with a different false-positive profile.
#   - Anything in a file the session never touched.
#   - The hostile case specifically: it reports presence, not intent. A zero-width run
#     inside a prompt-shaped sentence and one inside a CJK string look identical here.
#
# CC_UNICODE_SCAN=off disables it. Fail-open on every error path.
{
  [ "${CC_UNICODE_SCAN:-on}" = "off" ] && exit 0
  [ "${CC_REMIND:-on}" = "off" ] && exit 0
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0
  command -v python3 >/dev/null 2>&1 || exit 0

  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  case "$tool" in
    Write|Edit|MultiEdit|NotebookEdit|Read) ;;
    *apply_patch|*create_new_file|*read_file) ;;
    *) exit 0 ;;
  esac

  file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.pathInProject // empty' 2>/dev/null)
  [ -n "$file" ] || exit 0
  [ -f "$file" ] || exit 0
  # Bound the read: a scanner that stalls on a 2 GB file is a latency bug, not a guard.
  # `tr -d` is load-bearing: BSD wc pads its output ("      26"), and the numeric
  # guard below would reject that as non-numeric and silently disable the whole hook.
  bytes=$(wc -c < "$file" 2>/dev/null | tr -d '[:space:]' || echo 0)
  case "$bytes" in ''|*[!0-9]*) exit 0 ;; esac
  [ "$bytes" -gt 2000000 ] && exit 0

  # One-shot per file per session: the same file is read and written repeatedly, and a
  # warning repeated on every touch is a warning nobody reads.
  sid=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty' 2>/dev/null)
  if [ -n "$sid" ]; then
    key=$(printf '%s|%s' "$sid" "$file" | cksum 2>/dev/null | cut -d' ' -f1)
    mark="${TMPDIR:-/tmp}/cc-unicode-$key"
    mkdir "$mark" 2>/dev/null || exit 0
    find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'cc-unicode-*' -type d -mmin +1440 -exec rmdir {} + 2>/dev/null
  fi

  report=$(python3 - "$file" <<'PY' 2>/dev/null
import sys, unicodedata
NAMED = {
    0x200B: "ZERO WIDTH SPACE", 0x200C: "ZERO WIDTH NON-JOINER",
    0x200D: "ZERO WIDTH JOINER", 0x2060: "WORD JOINER",
    0xFEFF: "ZERO WIDTH NO-BREAK SPACE (BOM)", 0x00AD: "SOFT HYPHEN",
    0x202A: "LEFT-TO-RIGHT EMBEDDING", 0x202B: "RIGHT-TO-LEFT EMBEDDING",
    0x202C: "POP DIRECTIONAL FORMATTING", 0x202D: "LEFT-TO-RIGHT OVERRIDE",
    0x202E: "RIGHT-TO-LEFT OVERRIDE", 0x2066: "LEFT-TO-RIGHT ISOLATE",
    0x2067: "RIGHT-TO-LEFT ISOLATE", 0x2068: "FIRST STRONG ISOLATE",
    0x2069: "POP DIRECTIONAL ISOLATE",
}
BIDI = set(range(0x202A, 0x202F)) | set(range(0x2066, 0x206A))
try:
    with open(sys.argv[1], "r", encoding="utf-8") as fh:
        lines = fh.readlines()
except Exception:
    sys.exit(0)

hits = []
for lineno, line in enumerate(lines, 1):
    for col, ch in enumerate(line, 1):
        cp = ord(ch)
        if cp == 0xFEFF and lineno == 1 and col == 1:
            continue                      # a leading BOM is a file encoding, not a hider
        if cp in NAMED or 0xE0000 <= cp <= 0xE007F:
            name = NAMED.get(cp) or unicodedata.name(ch, "UNICODE TAG CHARACTER")
            hits.append((lineno, col, cp, name, cp in BIDI))
        if len(hits) >= 6:
            break
    if len(hits) >= 6:
        break

if not hits:
    sys.exit(0)
bidi = any(h[4] for h in hits)
out = []
for lineno, col, cp, name, _ in hits:
    out.append(f"line {lineno}, col {col}: U+{cp:04X} {name}")
print(("BIDI\n" if bidi else "PLAIN\n") + "\n".join(out))
PY
  )
  [ -n "$report" ] || exit 0

  kind=$(printf '%s' "$report" | head -1)
  body=$(printf '%s' "$report" | tail -n +2)
  base=$(basename "$file")

  if [ "$kind" = "BIDI" ]; then
    lead="secret-scanning: \`$base\` contains BIDIRECTIONAL OVERRIDE characters. These reorder how source is DISPLAYED without changing how it executes, so what you and a reviewer read is not what the compiler runs — the Trojan Source class (CVE-2021-42574). Treat this file's visible content as unverified until the characters are removed or explained."
  else
    lead="secret-scanning: \`$base\` contains ZERO-WIDTH or invisible characters. They do not render and survive copy-paste; in text that reaches a model they can carry instructions a human reviewer cannot see. Legitimate in emoji sequences and in Arabic/Persian/Indic text — decide which this is."
  fi

  jq -cn --arg c "$lead
$body
Silence with CC_UNICODE_SCAN=off. This warns once per file per session and never blocks." \
    '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$c}}' 2>/dev/null
  exit 0
} 2>/dev/null
exit 0
