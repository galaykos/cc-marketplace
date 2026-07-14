# rollout

Per-feature rollout planning: feature flags, backward compatibility, staged
exposure (internal → percentage → full), migration sequencing
(expand-migrate-contract), and a rollback path stated BEFORE ship.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install rollout@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/rollout:plan [feature-description]` | Produce a rollout plan for a feature about to ship — flag strategy, compatibility window, exposure stages, rollback trigger and path |

The plan is output as a table with one row per stage (stage / exposure / gate
metric / rollback trigger), followed by the rollback path — flag off, deploy
revert, or data restore — and whether it has been exercised. If the plan
involved significant choices, it offers to record them as an ADR via the
decision-records plugin.

## Example

```bash
/rollout:plan checkout switch from Stripe Charges to Payment Intents
/rollout:plan            # asks what is shipping, what data it touches, who sees it
```

The `rollout-planning` skill also fires on its own before shipping any
user-facing or data-touching change, so the rollback path is planned while it
is still cheap.

## Pairs well with

- **decision-records** — record significant rollout choices (dual-write vs dual-read, flag granularity) as ADRs
- **resilience** — failure-mode review of the code the rollout will expose
- **devops** — CI/CD pipeline and deploy config review for the ship itself
- **database** — schema and migration review behind expand-migrate-contract sequencing
