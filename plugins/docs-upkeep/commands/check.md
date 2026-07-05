---
description: "Scan the current change (or repo) for documentation drift — README claims, changelog gaps, stale examples, dead links — and list exact fixes."
---

# Documentation Drift Check

1. **Determine scope from $ARGUMENTS.** If arguments name files, directories, a commit range, or "repo", scan that. Otherwise default to the current change: uncommitted work (`git diff` + `git diff --staged` + untracked files), and if the working tree is clean, the branch diff against the default branch (`git diff <default-branch>...HEAD`).

2. **Apply the docs-upkeep skill's drift catalog** to the scoped change. For each behavior, interface, setup step, command, flag, env var, or default that the change touches, check the corresponding documentation surfaces: README (setup steps, feature claims, command examples, badges/versions), CHANGELOG (entry per user-visible change, in the project's format), API docs and docstrings (signatures, params, return shapes, runnable examples), configuration docs (new/removed env vars, defaults), architecture docs and ADR links (standing ADRs that the change supersedes), and inline examples/snippets (do they still execute). Also scan the touched docs for freshness signals: versions/dates in prose, "currently/for now/soon", stale TODO markers, moved relative links, commands referencing removed flags.

3. **Output one line per drift found**, in the format:

    doc-path:line — what drifted — the fix

   Group lines by document. If no drift is found, say so explicitly and list which surfaces were checked.

4. **Offer to apply the fixes.** Offer as a selectable choice (AskUserQuestion): "Apply all fixes now
   (Recommended)" / "Let me pick a subset" / "Skip". Plain fix list only
   when headless. On approval, edit the documents so the doc updates ride in the same change that caused them — do not defer to a follow-up.
