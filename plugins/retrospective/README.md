# retrospective

Post-milestone learning loop: a five-minute retro after a task run or feature
lands — surprises become CLAUDE.md candidates, repetition becomes skill
suggestions, friction becomes process tweaks. Closes the amnesia gap where
every run starts smart and ends forgotten.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install retrospective@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/retrospective:run [scope]` | Run a five-minute retrospective on the work just completed — surprises, friction, learnings — and route each into its sink (CLAUDE.md, skill suggestion, process tweak) |

## Example

```bash
/retrospective:run                    # most recent completed run in this session
/retrospective:run the auth milestone
```

The retro proposes, never silently writes: CLAUDE.md lines are offered as
multi-select choices, and a suggested skill can be scaffolded on the spot
(as `/claude-authoring:new-skill` would) or skipped. Output stays under a
page — a retro longer than the work it reviews is theater.

## Pairs well with

- **hindsight** — mines past session transcripts for cross-session friction; retrospective banks lessons from the session you are in
- **claude-authoring** — scaffolds the skills the retro suggests
- **task-runner** — the task runs whose completion is the natural retro trigger
