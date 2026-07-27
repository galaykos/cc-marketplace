# code-architecture

Engineering process for code-level structure: plan-before-code, YAGNI checks,
SOLID applied with judgment, task orchestration, work verification, low-
cognitive-load code, and KISS/DRY simplicity — plus always-on surgical-coding
discipline (surface assumptions, every changed line traces to the request, clean
up your own orphans), after Karpathy's LLM-coding guidelines.

Owns code-level structure — units, interfaces, file placement. Defers system-
level topology (service boundaries, scaling, caching) to the `system-design`
plugin.

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
`surgical-coding`, `low-cognitive-load`, `simplicity-principles` (KISS/DRY),
`solid-principles`, `yagni-check`, `task-orchestration`, `work-verification`, and
`drift-review`. The `architecture-reviewer` agent reviews structural changes for
boundaries, cohesion, and cognitive load.

`work-verification` and `drift-review` are the two done-time gates and they ask
different questions: `work-verification` asks whether the evidence backs the claim,
`drift-review` asks whether the work that produced it stayed on the task that was
asked. Cooperative, not tamper-proof — neither is a security boundary.

## Hook: the evidence gate

`work-verification`'s "never assert without output" rule has mechanical teeth: a
**Stop hook** (`hooks/evidence-gate.sh`) blocks a turn that claims completion
(done / fixed / implemented / verified / passes) after editing files when **no
command was executed after the last edit** — the exact shape of the later
apology "you're right, I didn't actually do it." The escape is honesty: prose
that names what is unverified ("not tested — run `npm test` to verify") passes.

Honest limits, stated up front: silence evades it (no claim, no judgment), and
any post-edit execution satisfies it — it proves *something* ran, not that the
right verification ran. One block per distinct claim; fail-open without jq or a
readable transcript. Downgrade with `CC_EVIDENCE_GATE=warn`, disable with
`CC_EVIDENCE_GATE=off`.

## Example

```bash
/code-architecture:plan add a webhook retry queue
/code-architecture:yagni app/Services/
/code-architecture:verify
```

## Pairs well with

- **system-design** — hands off service boundaries, scaling, and caching topology
- **taskmaster** — supplies the plan-before-code and work-verification gates the pipeline runs
- **task-runner** — applies the work-verification discipline across a task run
