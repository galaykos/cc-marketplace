# One-shot state: the worked case

A hook that must act only once per file, or once per context, records that it
acted. That record is the bound on its own behaviour. This file is the failure
that bound produced in practice, because it is short, it is easy to repeat, and
a full test suite stayed green through it.

## The shape

```sh
sid=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty')
marker="$cwd/.claude/<plugin>/blocked-$sid-$filehash"     # ← the bug
[ -e "$marker" ] && exit 0
mkdir -p "$cwd/.claude/<plugin>" || exit 0
: > "$marker" || exit 0
```

`session_id` is `a1b2c3d4-5e6f-...`, so during development that marker is:

```
/repo/.claude/p/blocked-a1b2c3d4-5e6f-7890-abcd-ef1234567890-9f8e7d
```

`transcript_path` is `/Users/you/.claude/projects/-repo/a1b2c3d4.jsonl`, so in a
real session the same line asks for:

```
/repo/.claude/p/blocked-/Users/you/.claude/projects/-repo/a1b2c3d4.jsonl-9f8e7d
                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                        directories that do not exist
```

`mkdir -p` created `/repo/.claude/p`, not the nested tree underneath it. Every
write failed. The fix is one pipe:

```sh
ctx=$(printf '%s' "$sid" | cksum | cut -d' ' -f1)
marker="$cwd/.claude/<plugin>/blocked-$ctx-$filehash"
```

## Why a failed write turned the gate OFF

The hook in question denies a write. Its author wrote a rule that is correct:

> a bound that cannot be recorded is not a bound — so if the marker cannot land,
> do not block at all

Without that rule a failed marker means blocking the same file forever and
wedging the session. With it, the sequence became:

1. try to write the marker → fails
2. cannot bound the deny → withhold the deny
3. exit 0, print nothing

The blocking logic was intact and unreachable. The plugin's README, skill and
command all still described a working gate. **Nothing in the transcript said the
tooth was gone.**

## The same line, three different symptoms

The mistake is about filenames, so the symptom depends only on what the marker
was for:

| Marker's job | Symptom when the write fails |
| --- | --- |
| "I already blocked this file" | never blocks at all |
| "I have warned 3 times, stop" | warns forever; and a companion filter that kept the run's own output out of its own baseline also died, so a large refactor could raise the baseline to match the code it had just written and certify itself |
| "I already surfaced this skill" | re-injects the same guidance on every edit — tokens spent per write, forever |

## Why the tests did not catch it

Every harness for those hooks built payloads like:

```sh
jq -n '{hook_event_name:"PostToolUse", session_id:"s1", cwd:$c, tool_input:{...}}'
```

No `transcript_path`. So 40+ cases exercised `.transcript_path // .session_id`'s
**fallback** arm, which was never broken, and the arm the host actually takes
never ran once. The suite was green, and green is what a maintainer trusts.

Add at least one case with a path-shaped `transcript_path`, and assert three
things — the hook still acts, the second call in the same context is bounded,
**and the marker file is actually on disk**. The third matters: without it, a
hook that has gone completely silent passes the "bounded" assertion vacuously,
because silence and correct-suppression look identical from outside.

## Checklist

- [ ] Read `.transcript_path // .session_id`, not `session_id` alone
- [ ] Hash it (`cksum`) before it appears in any path
- [ ] Decide, and write down, what a failed marker write means for your hook
- [ ] Test with a path-shaped `transcript_path`
- [ ] Assert the marker landed, not only that the second call was quiet
- [ ] Watch the test fail against the unfixed hook before trusting it

## Standing

In this marketplace the first two lines are **gates** — `pc_context_key` fails a
PostToolUse hook keyed on `session_id` alone, and `pc_marker_key` fails one that
interpolates the key raw into a path. The test-payload line is a gate too:
`pc_harness_payload` fails a harness that exercises a context-keyed hook while
sending only `session_id`. All three live in `scripts/lib/plugin-checks.sh`.

Outside this repo none of that travels with you. There, this file is
**recorded** — it is a checklist a reader has to choose to apply, and saying so
is the point.
