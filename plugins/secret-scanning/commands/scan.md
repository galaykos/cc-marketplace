---
description: Sweep a path, diff, or the whole repo for already-committed secrets against the secret-scanning patterns
argument-hint: [path-or-diff]
---

Scan existing content for leaked credentials — the on-demand complement to the
write-time guard hook.

1. Determine scope from $ARGUMENTS — a path, a diff/branch reference, or nothing
   (default: the whole tracked tree, or the staged diff if one exists). Prefer
   scanning tracked files; skip `.git/`, `node_modules/`, `vendor/`, and lockfiles.

   **Whole-tree scope goes to a subagent.** A default-scope run reads every tracked
   file in the repository and the finding list is a few lines — the widest
   read-to-return ratio here. Dispatch steps 2-3 with the Agent tool, and because a
   subagent cannot invoke a skill, resolve `secret-scanning`'s installed `SKILL.md`
   to an absolute path and put a `Read <abs-path>` line in the prompt; a sweeper
   working from a paraphrased pattern list is scanning for the wrong things. Require
   back only the step-3 finding lines, and instruct it to quote **at most the matched
   token's first 4 and last 4 characters** — never a whole credential, which would put
   the secret in this transcript, the exact exposure the command exists to close.
   A named-path or staged-diff scope is small: run it inline. Steps 4-5 — the
   remediation call and the AskUserQuestion — stay in this thread regardless.

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
