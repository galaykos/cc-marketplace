---
description: Run a build-vs-buy check on a capability before implementing it — existing-solution search, health table, take/wrap/write verdict.
---

Run the build-vs-buy protocol from this plugin's skill on $ARGUMENTS (if empty,
ask which capability is about to be implemented).

1. Name the generic capability in one line, stripped of project vocabulary.
2. Check the stdlib/framework first, then search the stack's registry
   (packagist/npm/pypi per the project's manifests) for established solutions.
3. Produce the candidate table: health (maintenance, adoption), license fit,
   coverage of the need (%), integration cost vs write-and-maintain cost.
4. Verdict: take / wrap / write — with the one-paragraph reason.
5. Significant verdict → offer as a selectable choice: "Persist as ADR now
   (Recommended)" / "Skip" — on yes, proceed as /decision-records:new would.
