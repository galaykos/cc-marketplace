---
description: "Scan the current change (or repo) for documentation drift — README claims, changelog gaps, stale examples, dead links — and list exact fixes."
---

# Documentation Drift Check

1. **Determine scope from $ARGUMENTS.** If arguments name files, directories, a commit range, or "repo", scan that. Otherwise default to the current change: uncommitted work (`git diff` + `git diff --staged` + untracked files), and if the working tree is clean, the branch diff against the default branch (`git diff <default-branch>...HEAD`).

2. **Load the docs-upkeep skill from this plugin and apply its drift catalog and freshness signals** to the scoped change — the catalog (which documentation surfaces to check per touched behavior) and the freshness-signal list are stated once in that skill; apply them from there rather than from any summary here.

3. **Output one line per drift found**, in the format:

    doc-path:line — what drifted — the fix

   Group lines by document. If no drift is found, say so explicitly and list which surfaces were checked.

4. **Offer to apply the fixes.** Offer as a selectable choice (AskUserQuestion): "Apply all fixes now
   (Recommended)" / "Let me pick a subset" / "Skip". Plain fix list only
   when headless. On approval, edit the documents so the doc updates ride in the same change that caused them — do not defer to a follow-up.
