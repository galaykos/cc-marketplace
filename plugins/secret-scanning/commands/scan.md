---
description: Sweep a path, diff, or the whole repo for already-committed secrets against the secret-scanning patterns
argument-hint: [path-or-diff]
---

Scan existing content for leaked credentials — the on-demand complement to the
write-time guard hook.

1. Determine scope from $ARGUMENTS: a range (`<base>..HEAD`; a bare branch name means
   `<branch>..HEAD`), one or more paths, or nothing — the whole tracked tree (`.`), or the
   staged files (`git diff --cached --name-only --diff-filter=d`) when something is staged.

2. Run the pattern scanner FIRST, before reading any file yourself:
   `bash "${CLAUDE_PLUGIN_ROOT}/scripts/scan-range.sh" <range | path…>`
   It applies the hook's own `hooks/patterns.tsv` to the lines a range added, or to whole
   files for a path. Exit 1: each stdout line is `file:line label (masked value)`, a
   **confirmed** hit. Exit 0: no pattern matched; stderr says how many lines were read.
   Exit 2: nothing was scanned — report its message and stop. Never substitute regexes of
   your own for the script's: its result is what the patterns say, not what you remember.

3. Then invoke the `secret-scanning` skill from this plugin and layer the review-time
   suspicions the patterns cannot carry (`.env`/config/CI files, connection strings on
   unlisted schemes, base64 blobs, committed `.pem`/`.key`, hardcoded fallbacks, a value
   split across lines). Each of those is **suspected** (needs a human look). Do not print
   a secret value in full; quote the script's masked form.

4. Output one line per finding:
   path:line — type — confirmed/suspected — why-it-looks-real — remediation
   Confirmed first, placeholders last.

5. For each confirmed secret, the remediation is: move to env/secret store, AND
   rotate the exposed credential (a committed secret is compromised regardless of
   later removal). Say so explicitly — do not imply deletion un-leaks it. A range reads
   added lines only, so a secret a later commit removed is still in history.

6. This is regex-and-heuristic, not proof of absence — end by recommending a full
   scanner (gitleaks, trufflehog) in CI for coverage the patterns miss; the script's exit
   code can gate a CI step too. When findings exist, offer via AskUserQuestion:
   "Remediate the confirmed leaks now (Recommended)" / "Report only". Headless: report only.
