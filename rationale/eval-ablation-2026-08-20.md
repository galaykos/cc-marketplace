# Control-vs-treatment ablation — 2026-08-20

First run of W1 from `rationale/distillation-strategy-2026-08-20.md`. Two skills,
two fixture designs, 18 runs, deterministic scoring.

**Result: zero measured delta in every arm.** Control matched treatment 3/3 on
both skills, and the only apparent treatment win was a bug in my own scorer.

---

## 1. Why this was not run with `claude plugin eval`

The official runner exists in the installed CLI (2.1.237) and is the right tool —
`--ablation with-without` is exactly this experiment — but it is **gated**:

```
$ claude plugin eval init --bare probe-case
`plugin eval` is currently in early access
```

`init` produced no files, so the `case.yaml` schema could not be read either.
The four suites authored today therefore use the **other** documented shape,
`prompt.md` + `graders/*.md`, which needs no schema guess. **They are unverified
against the runner** — nobody has executed them — and that is stated here rather
than implied by their existence. When the account is enabled, run:

```bash
claude plugin eval ./plugins/php --ablation with-without --runs 3 --json /tmp/php.json
```

The gate is an account-level access control. It was not worked around.

## 2. Method

| | |
| --- | --- |
| Arms | control = the fixture alone · treatment = the fixture plus the skill BODY verbatim |
| Blind | each run is a fresh subagent that sees only its own arm; no run knows an experiment exists, what is graded, or that another arm exists |
| Runs | n=3 per arm per case (τ-bench, arXiv 2406.12045: single-run agent measures are worthless — pass^8 <25% where pass@1 is ~50%) |
| Model | **Sonnet**, both arms. Results do not transfer across models; a stronger model plausibly needs the skill less, a weaker one more |
| Scoring | a Python regex scorer, `scratchpad/ablation/score.py`, not an LLM judge — MT-Bench (arXiv 2306.05685) documents judge verbosity bias, which is adversarial to grading a treatment whose claim is "says the right thing", not "says more" |
| Code criteria | searched inside fenced blocks only, so naming a feature in order to RULE IT OUT is not punished |

Cases are the shipped suites: `plugins/php/evals/floor-vs-idiom/` and
`plugins/nextjs/evals/caching-inversion/`.

## 3. Round 1 — the manifest pasted into the prompt

| Case | Arm | Pass | Mean answer chars |
| --- | --- | --- | --- |
| php (modernise to the pinned floor, `^8.1` + `config.platform`) | control | **3/3** | 2,802 |
| php | treatment | **3/3** | 2,424 |
| nextjs (is the reviewer's "Next caches fetches by default" right on 15?) | control | **3/3** | 2,762 |
| nextjs | treatment | **3/3** | 2,180 |

No control run shipped 8.2+ syntax at an 8.1 floor. No control run agreed with
the stale reviewer; every one named the Next 15 inversion and the correct remedy.

### The scorer lied once, and the correction is the point

The first scoring pass reported nextjs control **2/3** — the only non-zero delta
in the entire experiment. The failing criterion was "does not ship
`cache: 'no-store'` as the fix", implemented as a substring search over fenced
code. The answer it failed had refuted the reviewer, named the v15 default, given
the right remedy, and offered an explicit `no-store` while saying it

> "wouldn't fix a bug, it would just make the (already-current) default explicit"

which is correct, not the failure mode. The regex could not tell a recommendation
from an annotated no-op. Corrected (the match must not sit within 500 chars of
already-default / behaviour-unchanged language), the run passes and **the delta
disappears**. Uncorrected, this document would have reported a treatment win
manufactured by its own instrument. The v1→v2 reasoning is kept in `score.py`.

## 4. Round 2 — the manifest on disk, which is the variable that was never tested

`rationale/stack-skill-baselines.md:39-44` kept every stack plugin on the theory
that they encode "version leverage maps **and lockfile-pinning behavior**", and
`:50-53` admits the second half was never exercised because "fixtures had no
manifests". `rationale/measured-zero-shapes.md:23-34` had already measured the
first half at zero, twice. So round 2 removed the paste: the agent gets a working
directory containing `composer.json`, `README.md`, and the target file, and must
go and look.

| Arm | Pass | Named `config.platform` explicitly | Mean answer chars |
| --- | --- | --- | --- |
| control | **3/3** | **3/3** | 1,940 |
| treatment | **3/3** | **3/3** | 2,899 |

Every control run opened `composer.json` unprompted, found `^8.1` **and** the
stricter `config.platform` pin, and modernised within it. The manifest-reading
behaviour that was the surviving justification for this plugin is **already the
model's default on this task**.

## 5. What this settles, and what it does not

**Settles (for `php-best-practices`, Sonnet, this task shape, n=3 per arm, two
fixture designs):** the skill produced no measurable improvement, including on
the manifest-reading case its own defence rests on. That closes the "strongest
untested claim in the marketplace" (`measured-zero-shapes.md:95-96`) in the
direction the shapes doc predicted. It is one skill and one task, not the
cluster.

**Does not settle:**

- **Other task shapes.** Both cases ask "does the answer contain fact X". Neither
  measures multi-file review, or a footgun surfacing where the model was not
  already looking. `php-best-practices` has ~14 lines of genuine (d)-class
  footguns (`in_array` strict flag, `foreach as &$item`, `ORDER BY` binding); no
  fixture here touches them.
- **Other models.** Sonnet only.
- **`nextjs-best-practices`.** Its control passed 3/3 — but this fixture pastes
  the version into the prompt AND asks about the single most-published Next 15
  change. That is the easiest possible case for the control. A harder one (a
  version-sensitive claim with no version in view) is the next experiment, and
  the stacks audit's prediction that nextjs is the cluster's strongest skill is
  **not** refuted by this run.
- **Anything about token cost.** Treatment answers were 14–21% shorter in round 1
  and 49% longer in round 2. n=3; do not read a trend into that.
- **The four suites' validity as `claude plugin eval` cases.** Unrun; see §1.

## 6. Files

| Path | What |
| --- | --- |
| `plugins/{php,nextjs,i18n,resilience}/evals/*/prompt.md` + `graders/*.md` | the four shipped suites (i18n and resilience authored, not yet run) |
| `scratchpad/ablation/score.py` | the deterministic scorer, with the v1→v2 correction recorded in place |
| `scratchpad/ablation/answers*/` | all 18 raw answers |

The scratchpad is session-local and will not survive. If the raw answers matter
later, copy them somewhere tracked before relying on them — this document is the
part that is meant to survive, and it deliberately reports numbers rather than
pointing at files that will vanish.
