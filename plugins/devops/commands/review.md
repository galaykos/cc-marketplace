---
description: Review CI/CD pipelines, Kubernetes manifests, deploy/secret config, Dockerfiles and compose files — devops-practices always, docker-best-practices when a Dockerfile or compose file is in scope
argument-hint: [path-or-diff]
---
Review the target in $ARGUMENTS against this plugin's rubrics — audit it, do not rewrite it.

Before reporting, validate mechanically against the artifact where a tool exists — `docker compose config`, `kubectl apply --dry-run=client`, `hadolint`, `actionlint` — and cite the output; a finding is verified only when a check backs it. You audit configuration, you do not run deploys. OWNERSHIP: this review owns CI/PRODUCTION containers and pipelines; a docker-compose DEV environment or a dev Dockerfile in scope is reviewed here too, under `docker-best-practices` — the skill table below decides which rubric a file gets, by what it deploys, not where it sits.

1. Determine scope from $ARGUMENTS — a file, directory, diff/branch reference, or
   design document. If empty, default to recent changes (`git diff` against the merge
   base, falling back to the latest commits).

2. Run a triage pass before the deep read. A trivial, single-file, or purely mechanical
   change earns a one-line verdict — state it and stop. Treat the change as risky and
   take the deep pass when it touches auth, data, migrations, or concurrency, OR spans
   more than 5 files, OR exceeds 300 changed lines (a NEW file counts its full length as
   changed).

   **Hand up when the scope is not this stack's alone.** If the resolved scope contains
   files outside this plugin's surface and `/code-review:review` is installed, hand the
   WHOLE scope to it and stop. It is the fan-in for overlapping review surfaces and
   loads every matching stack skill in one pass; running the per-stack commands
   separately is what produces the duplicate findings the fan-in exists to prevent, and
   leaves the stacks nobody happened to invoke unreviewed. Deferring is not a smaller
   answer — the aggregator reaches this plugin's rubric too.

3. Load the skills from this plugin and apply each across every file in scope, not only
   the first match:

   | Evidence | Skill |
   |---|---|
   | CI config, Kubernetes manifest, deploy or secret config (always in scope) | `devops-practices` |
   | `Dockerfile*`, `docker-compose*.yml`, `compose*.yml` | `docker-best-practices` |

   For the Docker rubric, read the project manifests (composer.json, package.json,
   .env.example) first and pin findings to the actual stack — flag image tags that
   contradict the manifests' version floors, missing `ext-*` requirements, and a compose
   file whose services do not match the DSNs the app reads. Cite each skill's rubric; do
   not restate it here. When unsure of a directive or API, verify against the official
   docs (https://docs.docker.com, https://kubernetes.io/docs) rather than answering from
   memory.

   Report every issue you find at step 4, including ones you are uncertain about or
   consider low-severity; step 5 is the filter, and a finding it drops costs less than a
   real bug silently withheld.

4. Report findings one line each, sorted by severity (critical, high, medium, low):
   `locator — severity — [CONFIRMED|PLAUSIBLE] problem — fix` — the
   locator is `path:line`, or the section/heading for a design-doc review. Mark a
   finding `CONFIRMED` only with a traced call path, an executed check, or a
   reproduction; absent the ability to execute, findings stay `PLAUSIBLE` — that is
   acceptable, not a failure. No finding without evidence and a concrete fix; no praise,
   no padding.

5. Close with a coverage inventory and a self-refute pass. State `Checked: …` and
   `Not checked: … (why)` so it is explicit what was covered, what was clean, and what
   was skipped — not only what broke. Then run one adversarial self-refute pass over
   every critical finding; if a finding does not survive it, drop or downgrade it with a
   note.

6. When findings exist, offer the next step as a selectable choice (AskUserQuestion):
   Apply all / Apply critical+high only / Report only. On an apply
   pick, dispatch the finding list down the static chain devops-engineer → task-runner:task-executor if installed → inline — never leave
   the user to retype findings as instructions. In a headless or non-interactive run,
   report only and print the apply command instead of dispatching.

You may close by recommending an ultra-assess re-run when the change was large or
high-risk — recommend it only, never self-execute it.
