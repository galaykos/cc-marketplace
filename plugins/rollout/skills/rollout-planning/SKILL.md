---
name: rollout-planning
description: Use before shipping any user-facing or data-touching change — to plan flags, backward compatibility, staged exposure, and the rollback path while it is still cheap to have one.
---

## Core rule

A rollback path invented during an incident is a gamble. At 3am, with errors
climbing and half the team asleep, is the wrong time to discover that the old
code can't read the new data. State the rollback path BEFORE ship, while it is
still cheap to have one — every other section here exists to make that
statement concrete instead of "we'll revert if it breaks."

## When to plan

Plan a rollout for:

- **Data migrations** — schema changes, backfills, moving data between stores.
- **API changes** — new required fields, changed semantics, removed endpoints;
  anything a consumer outside this deploy depends on.
- **User-facing behavior** — new flows, changed defaults, pricing, permissions.
- **Config/infra flips** — cache strategy, queue driver, DNS, TLS, provider swaps.

Skip the ceremony for:

- Internal refactors fully behind passing tests — no external contract moved.
- Copy tweaks and cosmetic changes with no behavioral or data consequences.

If unsure which bucket a change is in, it touches data or users — plan it.

## Flag discipline

- **Flag per behavior, not per deploy.** One flag guards one decision the system
  makes. A `release_2026_07` flag that gates five behaviors can only roll back
  all five at once.
- **Kill-switch semantics.** Flag OFF must mean the exact pre-ship behavior, not
  a degraded hybrid. If turning the flag off doesn't restore yesterday, it is
  not a kill switch — it's decoration.
- **Every flag gets a removal date.** Flag debt is real debt: dead branches,
  untested combinations, config nobody dares touch. Write the removal date into
  the flag definition when you create it, not "after things settle."
- **Naming:** `<area>_<behavior>`, boolean reads as the new behavior when true —
  `pricing_use_v2_calculation`, not `new_stuff` or `temp_fix_2`.

## Backward compatibility window

Old and new must coexist during the rollout — during a percentage stage, both
code paths run at once, and during a deploy, old and new instances overlap.

- **API versioning:** never change the meaning of an existing field. Add a new
  field or a new version; retire the old one after consumers migrate.
- **Tolerant readers:** consumers ignore fields they don't recognize, so the
  producer can ship additions before every reader updates.
- **Dual-write vs dual-read:** dual-write keeps both stores current (safe reads
  anywhere, but write-path bugs corrupt both); dual-read writes one place and
  compares on read (cheaper, surfaces diffs, adds read latency). Prefer
  dual-read for verification, dual-write when a cutover deadline forces it.
- Declare the window's end: which release drops the compatibility shims.

## Migration sequencing: expand → migrate → contract

1. **Expand** — add the new column/table/endpoint alongside the old. Nothing
   reads it yet. Reversible by dropping the unused addition.
2. **Migrate** — backfill, then move readers and writers over behind the flag.
   Reversible by pointing the flag back at the old path.
3. **Contract** — remove the old column/endpoint only after nothing references
   it and the bake time has passed.

Each step ships independently and reverses independently. Never be destructive
in the same release that stops writing: the release that stops writing the old
column and the release that drops it must be different releases, or there is no
release you can roll back to.

## Exposure stages

    Stage        Exposure            Gate metric              Bake time
    internal     team / dogfood      error rate flat          1-2 days
    percentage   1-5% of traffic     gate metric holds        24-48h
    full         100%                gate metric holds        until flag removal

- Every stage has a **gate metric** — error rate, p95 latency, or a business
  KPI (conversion, support tickets). "Looks fine" is not a metric.
- Every stage has a **bake time** — long enough to cover the traffic pattern
  the change is sensitive to (a billing change needs a billing cycle).
- Name **who or what advances the stage**: a person reading a dashboard, or an
  automated check. Unowned stages advance on optimism.

## Rollback

- **Trigger:** a concrete threshold decided now — "error rate > 0.5% for 5
  minutes" or "any pricing diff on the comparison stage." Not "if it looks bad."
- **Path:** flag off (seconds, preferred), deploy revert (minutes, needs the
  old code to still work against current data), or data restore (hours, the
  hard one — plan it FIRST, because if data rollback is impossible you must
  know that before ship, not during the incident).
- **The test:** was the rollback path ever exercised? A flag that has never
  been flipped off in staging, a restore never rehearsed — those are hopes,
  not paths. Flip the flag off once before the percentage stage.

## Worked micro-example

New pricing calculation:

    Flag:     pricing_use_v2_calculation (removal date: +30 days after full)
    Stage 1:  internal — team accounts, error rate flat, 2 days
    Stage 2:  dual-read comparison on 1% traffic — serve v1, compute both,
              log diffs. Gate: zero diff for 48h. Trigger: any diff -> flag off.
    Stage 3:  serve v2 at 5% -> 50% -> 100%, gate error rate + support tickets
    Contract: remove v1 path and flag at the removal date

The dual-read stage means v2 cannot mischarge anyone before it has proven
itself against v1 on real traffic.

## Boundaries

- Pipeline and deploy mechanics (CI gates, canary infra, blue-green) belong to
  the devops plugin's devops-engineer agent.
- Dialect-level migration DDL (locks, `ALGORITHM=INPLACE`, concurrent indexes)
  belongs to the database plugins.
- This skill owns the per-feature plan: flags, compatibility window, stages,
  rollback. At each handoff offer the next step as a selectable choice, one
  offer per moment, bare commands only when headless: contested choices —
  "Record as ADR now (Recommended)" / "Skip" (as /decision-records:new
  would); step list ready — "Execute with the task runner now (Recommended)"
  / "Skip" (as /task-runner:run would); auth, money, or PII touched — "Run
  the security review before stage 1 (Recommended)" / "Skip" (as
  /security:review would).

## Anti-patterns

- **Flagless big-bang** — 0% to 100% in one deploy, rollback = full revert
  under pressure.
- **Flags that never die** — every long-lived flag doubles the untested state
  space.
- **Rollback = "revert and pray"** — a revert nobody verified against
  already-migrated data.
- **Advancing stages on vibes** — "it's been quiet" without checking the gate
  metric it was supposed to hold.
