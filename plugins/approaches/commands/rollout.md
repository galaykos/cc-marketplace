---
description: Produce a rollout plan for a feature about to ship — flag strategy, compatibility window, exposure stages, rollback trigger and path.
argument-hint: [feature-description]
---

1. Take the feature to roll out from $ARGUMENTS. If empty, ask the user what is
   shipping — what changes, what data it touches, and who sees it — before doing
   anything else.
2. Apply the rollout-planning skill from this plugin: decide the flag strategy,
   the backward compatibility window, migration sequencing if data is involved,
   exposure stages with gate metrics, and the rollback trigger and path.
3. Output the plan as a table with one row per stage: stage / exposure / gate
   metric / rollback trigger. Below the table, state the rollback path (flag off,
   deploy revert, or data restore) and whether it has been exercised.
