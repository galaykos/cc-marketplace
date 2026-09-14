# code-architecture

Engineering process for code-level structure: plan-before-code, YAGNI checks,
SOLID applied with judgment, task orchestration, work verification, and
low-cognitive-load code. KISS/DRY and the surgical-edit discipline (surface
assumptions, every changed line traces to the request, clean up your own
orphans — after Karpathy's LLM-coding guidelines) travel as references of the
two skills that own them, not as separate always-on triggers.

Owns structure at both levels. Code: units, interfaces, file placement. System:
service boundaries drawn on data ownership, scaling paths, cache placement, sync vs
async integration and its failure modes, single points of failure, and domain
modeling (bounded contexts, aggregates, ubiquitous language) — the `system-design`
and `domain-modeling` skills and the `system-architect` worker (the system-design
plugin was merged into this one on 2026-09-14). Message-driven architecture (delivery
semantics, outbox, sagas, DLQ) lives in `resilience`'s `event-driven` skill.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install code-architecture@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/code-architecture:plan` | File-level implementation plan before writing code — which files change, unit ownership, interfaces |
| `/code-architecture:yagni` | Audit code or a design for speculative generality |
| `/code-architecture:solid` | Audit code or a design for SOLID violations |
| `/code-architecture:verify` | Verify completed work against its success criteria, with evidence |

## Skills & agent

Best-practice skills auto-trigger by context — `plan-before-code`,
`low-cognitive-load`, `solid-principles`, `yagni-check`,
`work-verification`, `drift-review`, `system-design`, and `domain-modeling`. The
`architecture-reviewer` agent reviews structural changes for boundaries, cohesion,
and cognitive load, and on a design doc or service topology audits against the
system-design rubric. The `system-architect` worker (opus floor) designs and
implements system-level structure: how services split, who owns which data, how
load scales, where caches sit, which integrations run async.

Two skills were merged away in 0.10.0 rather than deleted: KISS/DRY is now
`low-cognitive-load/references/kiss-dry.md`, and the surgical-edit discipline is
`plan-before-code/references/surgical-edits.md`. Both had descriptions reading
"when writing or reviewing code", which fires on every edit and discriminates
nothing; folding them cut two always-on triggers while keeping every line of the
material.

`work-verification` and `drift-review` are the two done-time gates and they ask
different questions: `work-verification` asks whether the evidence backs the claim,
`drift-review` asks whether the work that produced it stayed on the task that was
asked. Cooperative, not tamper-proof — neither is a security boundary.

## The evidence gate lives in candor

`work-verification`'s "never assert without output" rule has mechanical teeth: a
**Stop hook** blocks a turn that claims completion (done / fixed / implemented /
verified / passes) after editing files when **no command was executed after the
last edit** — the exact shape of the later apology "you're right, I didn't
actually do it." The escape is honesty: prose that names what is unverified
("not tested — run `npm test` to verify") passes.

Until 2026-09-14 that hook shipped here as `hooks/evidence-gate.sh`. It is now
clause 3 of `candor`'s one Stop gate (`plugins/candor/hooks/gate.sh`), so this
plugin ships no hook and the rule has teeth only with candor installed —
`quality-suite` and `taskmaster-suite` carry both. Honest limits, unchanged:
silence evades it, and any post-edit execution satisfies it. `CC_EVIDENCE_GATE=warn|off`
still downgrades that clause alone.

## Example

```bash
/code-architecture:plan add a webhook retry queue
/code-architecture:yagni app/Services/
/code-architecture:verify
```

## Pairs well with

- **resilience** — owns the `event-driven` skill (brokers, outbox, sagas, DLQ) and
  the failure modes of the topology this plugin draws
- **taskmaster** — supplies the plan-before-code and work-verification gates the pipeline runs
- **task-runner** — applies the work-verification discipline across a task run
- **candor** — carries the Stop gate whose clause 3 is this plugin's evidence
  rule; install it or the rule is prose
