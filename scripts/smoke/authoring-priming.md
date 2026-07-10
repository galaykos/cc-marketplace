# Smoke: authoring-time skill priming (LOCAL, not CI)

Proves the C-path mechanism actually **fires** in a delegated implementer — the
static `validate.sh` guard only proves the instruction is *present*. This harness
needs a live model, so it is local/manual and is **not** a CI gate (CI is
model-less: only `validate.sh` + `check-version-bumps.sh` run there).

## Why a canary token

A delegate can recite a well-known rule ("test behavior, not implementation")
straight from pretraining without ever reading the skill. So we inject a **unique
nonsense token** into the target `SKILL.md` only — absent from the thinned agent
body and from pretraining — and assert the delegate echoes it. Echo ⇒ it Read the
real file.

## Procedure (per tier)

```bash
# 1. Inject the canary into the tier's target skill (installed copy).
bash scripts/smoke/canary.sh inject testing-best-practices      # T1 pilot
#   (T2 cross-plugin: docker-best-practices — exercises cross-plugin resolution)

# 2. Run a fixture card through the REAL dispatch so a delegate is spawned with the
#    injected `Read <abs-path>` line. e.g. a "write a test for <fixture>" card via
#    /task-runner:run, or dispatch the worker agent directly on a fixture task.

# 3. Assert: the delegate's returned report contains CANARY-ZXQ7-DELEGATE-READ-PROOF.
#    Present  -> the Read fired inside the delegate context. PASS.
#    Absent   -> the priming did not reach the delegate. FAIL — investigate the
#                resolver / dispatch injection before shipping the tier.

# 4. Always clean up (removes the token from every installed SKILL.md).
bash scripts/smoke/canary.sh clean
```

`canary.sh path <skill-dir>` prints the resolved absolute path without injecting —
useful to confirm the resolver targets the newest installed version.

## Results log

| Date | Tier | Skill | Delegate | Token echoed? |
|------|------|-------|----------|---------------|
| _pending_ | T1 | testing-best-practices | test-engineer | _run card 08_ |
| _pending_ | T2 | docker-best-practices | devops-engineer | _run card 12_ |
| _pending_ | T3 | livewire-best-practices | (generic card subagent) | _run card 14_ |
