# Changelog — devops

Consumer-facing changes only. Newest first.

## 0.6.3

### Changed
- **Worker agents default to no comment.** The "Code shape" section no longer says
  "match the surrounding file's comment density". The default is no comment; a comment
  is one line for a fact the code cannot show, a docblock that repeats the signature is
  deleted, and only a house style stated in the project's CLAUDE.md overrides it. The
  matching hooks (deny lanes and the 0.4:1 ceiling) ship in code-review.

## 0.6.2

### Changed
- In-code instrumentation is deferred to resilience's observability skill and
  `/resilience:observability-review`; the observability plugin merged into resilience on <!-- removed-ok -->
  2026-09-02.

## 0.6.1

### Added
- **dev-env merged in.** `docker-best-practices` and `compose-init` are devops skills; <!-- removed-ok -->
  `/devops:init` generates a local compose environment from evidence, and
  `/devops:review` loads the Docker rubric whenever a Dockerfile or compose file is in
  scope. The old ownership split (prod containers here, dev compose there) is gone: one
  review, the skill table decides the rubric by what the file deploys.

## 0.5.9

### Changed
- **Meta-prose compressed to a one-line standing tag.** Sections narrating this
  skill's relationship to its siblings — boundary tours, "what this is NOT" lists,
  and in places the repository's own drift history — are replaced by a `Standing:`
  line on the rule they qualify. No actionable rule changed, and every named
  cross-skill reference was preserved: those names are what make the skills they
  point at reachable, and a re-scan confirmed none was orphaned.

## 0.5.8

### Changed
- **Every hook entry now declares a `timeout`.** `workflow-guard.sh` 15s. Before this release the
  plugin expressed no opinion about how long its own hook may hold a turn and
  relied entirely on the host default; a hook that blocks — a slow network mount,
  a large transcript — stalled the user with no per-hook ceiling. Sizes are per
  script, not one house number: 5s for a jq-only classifier, 10s for git/find
  work, 15s where the script shells out to the network, a package manager or
  node. No hook logic changed.

## 0.5.7

### Changed
- **`devops-reviewer` names the standing of its PROACTIVELY clause**: `recorded`
  — nothing dispatches the reviewer automatically after engineer output; the
  host heuristic and an explicit `/devops:review` are the only paths. Config
  shipped without the audit was not reviewed, and the agent now says so.
- Worker agents regenerated from the shared template: findings are confirmed
  against the code before any change (see the marketplace-wide template change).

## 0.5.6

### Changed
- **`/devops:review` hands the whole scope to `/code-review:review`** when the resolved
  scope reaches outside this plugin's stack surface and that plugin is installed.
  `code-review` already declared itself the fan-in for overlapping review surfaces, but
  only the aggregator knew it — entering through a stack command left the other stacks
  in a multi-stack diff unreviewed, or produced the duplicate findings the fan-in exists
  to prevent. The clause lives in `templates/blocks/triage.md`, shared by all 26
  generated stack reviews.

## 0.5.5 — 2026-08-16

### Added
- **`lane.tsv`** — `devops-reviewer` declares `pipeline-and-deploy-config-review` and
  yields to `dev-env:review` on local compose environments, which is the boundary the
  two plugins' descriptions already asserted and no gate previously checked.

## 0.5.4 — 2026-08-15

### Changed
- **`agents/devops-engineer.md`** — re-stamped from the shared worker-agent template,
  which gained a cost-discipline paragraph in its `## Code shape` section: default to
  the smallest change that satisfies the fix list, name the trigger when exceeding it,
  and never cut a test to hit a ratio. Applies to all ten template-generated workers;
  no devops-specific behavior change beyond that shared paragraph.

## 0.5.2 — 2026-08-12

### Changed
- **`agents/devops-engineer.md`** — re-stamped from the shared worker-agent
  template, which now wraps the rubric-source sentence in a preserve block so a
  single agent can carry bespoke wording without opting out of the template. No
  behavior change for this agent; its rubric text is byte-identical inside the
  block.

## 0.5.1 — 2026-08-11

### Changed
- `devops-engineer` (chassis-regenerated) gains the shared **Code shape** section:
  match the surrounding file's naming, idiom, and comment density; comments state
  constraints the code cannot show, never narrate the edit; new behavior no test
  exercises is named as untested in the agent's return.

## 0.5.0 — 2026-08-02

### Added
- **`scripts/workflow-audit.sh`** — a GitHub Actions trust-boundary audit. Six
  rules; exit 2 on a critical finding, 0 otherwise, so it wires into your CI as
  one line. Criticals are the two shapes with no legitimate form:
  `pull_request_target`/`workflow_run` checking out the untrusted head, and an
  author-controlled `${{ github.event.* }}` field interpolated into a `run:` block.
  Warn-level: third-party actions pinned to a mutable tag, no top-level
  `permissions:`, a self-hosted runner on a fork-reachable trigger, and secrets
  reachable from a fork trigger.
- **`hooks/workflow-guard.sh`** — a PreToolUse hook denying those two critical
  shapes at the moment a workflow file is written. It denies nothing else on
  purpose: a deny that fires on ambiguous cases gets switched off and takes the
  unambiguous ones with it.

### Changed
- `devops-practices` gains a row in its mechanical-validation table for the audit,
  and states what it covers that `actionlint` does not — who the workflow trusts.

### Notes
- The audit is a line-oriented scan, not a YAML parser. A clean run means "none of
  the six known shapes are present in these files", never "this pipeline is safe".
- Rule 2 matches attacker-controlled fields by LEAF, not by prefix:
  `github.event.pull_request.base.sha` is generated by GitHub and is not a finding.
  An earlier draft flagged it, which is the false-positive class that gets a gate
  disabled.
