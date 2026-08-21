# What the host's own skill levers actually do — measured, not read

W5 of `rationale/distillation-strategy-2026-08-20.md` proposed adopting two
frontmatter fields this marketplace has never used: `paths:` (glob-gated
activation) and `disable-model-invocation:` (removes a skill's description from
context). Both were taken from the docs. Both were then probed against the
installed build — **Claude Code 2.1.237** — because the docs describe what the
fields mean, not what they cost, and W5's whole case was a token argument.

The probes changed the plan. One lever does nothing for a marketplace; the other
works and has no safe target here; and the official meter is wrong about both.

---

## 1. Method

Two probe skills per scope, identical except for the field under test, each
carrying a unique magic word so activation is observable rather than inferred:

| Scope | How it was installed |
| --- | --- |
| project | `.claude/skills/<name>/SKILL.md` in a scratch directory |
| plugin | a scratch marketplace + `claude plugin install`, **uninstalled and the marketplace removed afterwards** — the user's global plugin config is back to what it was |

Each run is a fresh headless `claude -p` in a scratch tree. Availability is read
two ways: the model's own listing ("list every skill name available to you") and
whether the magic word can be produced.

## 2. `paths:` — measured semantics

| Condition | Project skill | Plugin skill |
| --- | --- | --- |
| No matching file anywhere | **hidden** from the listing; `/pathprobe` → `Unknown command: /pathprobe` | **LISTED** |
| Matching file present in the tree, untouched | **hidden** | listed |
| Matching file **read** | **hidden** | listed |
| Matching file **written / edited** | **activates** — body available | activates |

Two facts worth separating, because the docs state neither:

1. **The trigger is an EDIT, not a read and not presence.** A `Read` of a
   matching file left the skill unavailable; a `Write` to it made the body
   available in the same turn. That is the same trigger model as this
   marketplace's own `skill-router` PostToolUse hook — natively, with no hook and
   no per-prompt token cost.
2. **`paths:` does not hide a PLUGIN skill from the listing.** Verified in a
   clean tree containing no matching file at all: `probe-mp:pluginpath` was
   listed anyway. So for a marketplace, `paths:` buys **zero always-on tokens**.

### What that kills

W5's step 2 — "move the 67 `rules.tsv` path-glob rows onto the skills themselves
and measure what remains of skill-router's dynamic cost" — was a token argument,
and the token saving is not there for plugin skills. It would also lose two
things the router does and `paths:` cannot: `stack_marker` suppression (vue3 vs
vue2 by manifest evidence) and rank arbitration between rows that co-fire.

### What survives

`paths:` is still the cheapest way to add an edit-time trigger to a **project or
personal** skill, where it does suppress the listing entry. Worth knowing when
advising users, worth nothing for the catalogue.

## 3. `disable-model-invocation: true` — works, exactly as documented

On a plugin skill, in a clean tree:

- **absent** from the model's listing — a real always-on saving, and the only
  lever measured here that produces one;
- `/probe-mp:pluginhidden` still runs and returns its body.

### Why nothing in this marketplace adopts it yet

The flag trades auto-triggering for the tokens. A skill is a safe target only if
it should never fire from a natural-language request. Every candidate examined
fails that test the same way the craft-layer set did (§8d of the strategy):
their triggers are **prompt-shaped**, not command-shaped. `taskmaster:ultra`
fires on the token `ultra-task` appearing anywhere in a prompt;
`hindsight:harvest` on "mine my past sessions"; `craft-layer:motion-tiers` on
"add smooth scroll". Removing the description removes the only channel each of
those has.

**Standing: recorded.** The lever is proven; the target set is empty today. A
skill written specifically as a command's implementation — no natural-language
trigger of its own — is the shape that would qualify, and none exists here.

## 4. A correction to W2: the official meter is wrong about both fields

`claude plugin details probe-mp`, on the plugin carrying all three probes:

```
component      always-on  on-invoke
pluginpath           ~50        ~30
pluginhidden         ~60        ~30
plugincontrol        ~60        ~30
```

`pluginhidden` is charged ~60 always-on tokens for a description the session
listing **does not contain**. So `claude plugin details` is a static estimate
over the files, not a read of what the harness loads. `scripts/context-budget.sh
--reconcile` compares against it and reports a 1.54x gap; that gap is now known
to include at least one over-charge the host itself would not levy. It remains
the better of the two meters for ordinary skills — the per-component floor is
real — but it is not ground truth, and the reconcile mode's comment says so now.

## 5. Residuals

- One build (2.1.237), one machine. A later version could hide plugin skills
  under `paths:`; re-run the probes before assuming today's answer holds.
- The probes measure LISTING PRESENCE and ACTIVATION, not dispatch quality. That
  a skill is listed says nothing about whether it wins against its neighbours.
- `paths:` activation was tested with `Write` and `Read` only. `Bash`-mediated
  edits (`sed -i`, `cat >`) are untested and plausibly do not trigger it, which
  would matter for any workflow that edits that way.
- The plugin-scope probe required installing into the user's real config,
  because the marketplace's installed copy is a cache snapshot rather than this
  working tree. It was removed immediately; `claude plugin list` and
  `marketplace list` were re-checked and show neither the probe plugin nor its
  marketplace.
