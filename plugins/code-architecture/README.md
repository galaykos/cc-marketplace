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
`solid-principles`, `yagni-check`, `task-orchestration`, and `work-verification`.
The `architecture-reviewer` agent reviews structural changes for boundaries,
cohesion, and cognitive load.

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
