# Changelog — devops

Consumer-facing changes only. Newest first.

## 0.8.0 — 2026-09-22

### Added
- **`scripts/plan-audit.sh` — a Terraform/OpenTofu plan reader with an exit code.**
  `terraform show -json plan.out | bash scripts/plan-audit.sh` (path or stdin) exits **2**
  when the plan deletes or replaces a resource whose type holds data — RDS, Aurora, S3,
  DynamoDB, EFS/EBS, Cloud SQL, GCS, Compute Disk, Azure storage account / SQL database /
  flexible server / managed disk, a PVC, and a `helm_release` only when its values or
  `set` blocks name one. `--list-types` prints the list with a reason per type. **1** means
  it could not read the input and nothing was checked; it fails CLOSED, unlike this
  plugin's hook, because the only other thing a reader can say about a plan it cannot
  parse is "clean". `/devops:review` runs it when `*.tf`/`*.tofu` or a plan JSON is in
  scope, and `devops-practices` carries the invocation. No hook: a plan arrives as a
  file, not as a tool call.
- The second half, `lifecycle.prevent_destroy = true` removed since `--base`, reads the
  `.tf` SOURCE in a git work tree (`--tf-dir`, `--base`), not the plan. Terraform does not
  record `lifecycle` in state and does not emit it in the JSON plan at all, so a
  plan-only check for it would have been theater; with no work tree to read, the reader
  prints `prevent_destroy: NOT CHECKED` and never "clean". Fixtures in
  `scripts/__tests__/plan-audit.test.sh` (28 asserts).
- What the reader does NOT catch is in its own header and the README: a resource type not
  on the list, another provider, a module that wraps storage under a type of its own, data
  loss inside an `update` (a shrunk volume, `skip_final_snapshot` flipped), a `moved`
  block, whether the destroy is recoverable, and a chart whose PVC never appears in the
  release's values. Untested against output a real `terraform` binary produced — no
  binary exists on the machine it was written on; the schema is honoured from
  HashiCorp's JSON output format docs, re-read 2026-09-22.
  Panel finding 43 (`rationale/specialist-panel-2026-09-22.md` §2): the marketplace had
  no IaC lane, and the mechanism-bearing slice of that gap is this reader, not a
  terraform skill — that shape is `rationale/measured-zero-shapes.md` shape 4.

## 0.7.1 — 2026-09-22

### Changed
- `compose-init`'s `Last verified` stamp carries a `version-tail-ok:` marker. The stamp
  points at an EOL calendar, not a package registry — the skill pins container image tags
  read from the project's manifests and depends on no package of its own — so
  `check-doc-staleness.sh --live` has nothing to compare and `pc_version_stamp_tail` was
  warning about a tail that cannot exist. The marker states that, and states that nothing
  machine-reads the EOL calendar either.

## 0.7.0 — 2026-09-22

### Fixed
- **Composite actions were a hole straight through both halves of the guard.** An
  identical `run: echo "${{ github.event.pull_request.title }}"` was denied in
  `.github/workflows/ci.yml` and allowed in `.github/actions/<name>/action.yml`, which a
  workflow calls with its own token — so the same command execution shipped through the
  side door. `hooks/workflow-guard.sh` now matches the composite path, and
  `scripts/workflow-audit.sh` reads `.github/actions/*/action.y{a,}ml` as a second root.
  Only rules 2 (expression injection) and 3 (unpinned third-party `uses:`) apply there;
  rules 1, 4, 5 and 6 read triggers, top-level `permissions:` and `runs-on`, fields a
  composite does not have, so applying them would warn on every composite in existence.
  Still not read: an `action.yml` outside `.github/actions/`, and a composite that shells
  out to a script file.
- **The deny reason named a path that does not exist on an installer's disk** —
  `plugins/devops/scripts/workflow-audit.sh` is this marketplace's own layout. It now
  resolves `${CLAUDE_PLUGIN_ROOT}` (falling back to the hook's own directory), so the
  command in the message is one the reader can paste.

### Changed
- Fixtures for every row above, both directions, in
  `scripts/__tests__/workflow-audit.test.sh`.
- `README.md`: the composite scope, and a **Running headless / in CI** note — this
  plugin's guard only ever denies, so it is headless-safe; the `ask` tiers belong to
  `command-guard` and `database`. Standing: recorded.

### Changed
- `lane.tsv` now declares the `devops-practices` skill (build phase, `cicd-and-deploy-idioms`); it was the plugin's headline skill and the only one with no lane row.

## 0.6.10 — 2026-09-22

### Fixed
- `commands/review.md` recommended an ultra-assess re-run without saying it is
  task-runner's and only exists when that plugin is installed.

## 0.6.9 — 2026-09-16

### Changed
- `agents/devops-reviewer.md` names the standing of its read-only claim (trend audit
  E4, `rationale/marketplace-trend-audit-2026-09-16.md`): Bash is granted for dry-runs,
  so "read-only" is the body's rule, not a tool restriction — recorded, not enforced.
- README states the boundary with the host's built-in `/init`, which writes a
  `CLAUDE.md`; `/devops:init` generates docker-compose (audit C3). `commands/init.md`
  carries the matching `<!-- host-ok -->` blessing for the extended host-overlap gate
  (audit C2).

## 0.6.8

### Fixed
- **`devops-engineer`'s defer rule was unreadable.** A search-and-replace had turned
  "dev environment" into "devopsironment", so the one line telling the worker to hand
  local compose generation to `/devops:init` named nothing a reader could parse. Fixed
  in `.chassis.json` and the rendered agent.

### Changed
- **The README's has-teeth table said warn findings exit 2; they exit 0.** Only a
  CRITICAL finding exits 2 from `workflow-audit.sh`, and 3 means it could not read —
  verified by running it. `devops-practices` had this right all along, so the two
  surfaces contradicted each other; the README now matches the script, names which
  four findings are warn-level, and states the residual the script's own header
  carries (a line scan, not a YAML parser: a clean run is "none of the six known
  shapes", never "safe").
- `devops-practices` drops the `# DevOps practices` heading that restated its own
  title — no rule removed. Four of the marketplace's skill bodies carried one; the
  other seven in this sweep never did.

## 0.6.7

### Fixed
- **`workflow-guard` now has an off-switch**, `CC_WORKFLOW_GUARD=off`. It previously had none.

## 0.6.6

### Fixed
- **Two removed plugins were named in always-on listing bytes.** `devops-practices`'
  description and the `devops-engineer` agent's routed work to `dev-env` and <!-- removed-ok -->
  `observability`, both absorbed into other plugins — text the CLI sends every session.
  They now name this plugin's own `compose-init` skill and `resilience`. `pc_removed_refs`
  gained `dev-env` so the next one fails the build instead of shipping. <!-- removed-ok -->

### Added
- **A "What has teeth" table.** The README described the PreToolUse guard in one clause
  and never said what it denies (two shapes: a `pull_request_target`/`workflow_run`
  workflow that checks out the untrusted head ref, and a `${{ github.event.* }}` field
  interpolated into a `run:` block), nor that `workflow-audit.sh` exists at all.
## 0.6.5

### Changed
- `devops-practices` hands in-code instrumentation to `/resilience:review --concern
  observability`: resilience collapsed its five review commands into one on 2026-09-14.
  The boundary (application emits, devops wires) is unchanged.

## 0.6.4

### Changed
- `lane.tsv` rows for this plugin's chassis-generated artifacts are now rendered by
  `scripts/generate.sh` from `lane` keys on its `.chassis.json` objects (a
  `# generated:start` … `# generated:end` block) instead of being typed by hand —
  same territory, trigger and yields_to; `generate.sh --check` fails if the two drift.
  No behaviour change for a user of the plugin.

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
  yields to `dev-env:review` on local compose environments, which is the boundary the <!-- removed-ok -->
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
