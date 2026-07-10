---
description: Sweep a path, diff, or the whole repo for already-committed secrets against the secret-scanning patterns
argument-hint: [path-or-diff]
---

Scan existing content for leaked credentials — the on-demand complement to the
write-time guard hook.

1. Determine scope from $ARGUMENTS — a path, a diff/branch reference, or nothing
   (default: the whole tracked tree, or the staged diff if one exists). Prefer
   scanning tracked files; skip `.git/`, `node_modules/`, `vendor/`, and lockfiles.

2. Invoke the `secret-scanning` skill from this plugin and apply its detection: the
   high-confidence provider patterns (AWS/GitHub/Slack/Google/Stripe keys, private-key
   blocks, assigned secret literals) PLUS the review-time suspicions (`.env`/config/CI
   files, credential-bearing connection strings, base64 blobs, committed `.pem`/`.key`,
   hardcoded fallbacks).

3. Output one line per suspected secret:
   path:line — type — why-it-looks-real — remediation
   Order real-looking hits first, placeholders last. Mark each as **confirmed**
   (matches a provider shape) or **suspected** (needs a human look).

4. For each confirmed secret, the remediation is: move to env/secret store, AND
   rotate the exposed credential (a committed secret is compromised regardless of
   later removal). Say so explicitly — do not imply deletion un-leaks it.

5. This is regex-and-heuristic, not proof of absence — end by recommending a full
   scanner (gitleaks, trufflehog) in CI for coverage the patterns miss. When findings
   exist, offer via AskUserQuestion: "Remediate the confirmed leaks now (Recommended)"
   / "Report only". Headless: report only.
