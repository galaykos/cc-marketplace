# Codex compatibility

Generated inventory. Skills preserve domain guidance; host-specific workflows use explicit
overrides. Hooks listed here are configured, not proof of live-host enforcement.

| Plugin | Skills | Hook events | Source limitations / replacement |
|---|---:|---|---|
| ui-ux | 16 | PostToolUse, SessionStart | {"preview-guard.sh": "Codex has no Claude Artifact event. Run a rendered preview and verify the UI before presenting it."} |
| craft-layer | 19 | UserPromptSubmit | {} |
| laravel | 3 | — | {} |
| code-architecture | 12 | SessionStart | {"evidence-gate.sh": "Automatic architecture transcript gating is unavailable. Before finalizing architecture work, explicitly verify the evidence checklist in the code-architecture skill."} |
| taskmaster | 15 | UserPromptSubmit, PreToolUse, PostToolUse, SessionStart | {"preview-guard.sh": "Codex has no Claude Artifact event. Follow the taskmaster preview protocol before presenting artifacts."} |
| git-workflow | 5 | — | {} |
| debugging | 2 | UserPromptSubmit | {} |
| task-runner | 7 | PostToolUse, Stop, PreToolUse, SessionStart | {"drift.sh": "Transcript drift detection is unavailable. Recheck the user request and active scope before each work batch.", "rv-observe.sh": "Claude Agent dispatch observation is unavailable. Record reviewer results explicitly using task-runner scripts.", "partial": ["Completion state and HEAD checks remain active; transcript-based reduction disclosure checks are unavailable. Explicitly name every reduction and its reason in the closing report."]} |
| stack-scan | 4 | — | {} |
| plugin-scout | 2 | — | {} |
| vercel-skills-scout | 2 | — | {} |
| testing | 4 | PostToolUse | {} |
| security | 5 | PostToolUse | {} |
| api-design | 8 | UserPromptSubmit | {} |
| web-dev | 4 | — | {} |
| system-design | 4 | — | {} |
| devops | 5 | PreToolUse | {} |
| database | 3 | PreToolUse | {} |
| code-review | 5 | PostToolUse, PreToolUse, SessionStart | {"verbosity.sh": "Transcript verbosity measurement is unavailable. Keep progress updates brief and focused on decisions and evidence."} |
| approaches | 10 | UserPromptSubmit, SessionStart | {} |
| hindsight | 2 | SessionStart | {"collect.sh": "Automatic transcript collection is unavailable. Use the hindsight reflection skill to record outcomes explicitly.", "skill-use.sh": "Codex does not emit Claude Skill tool events. Record useful skill outcomes explicitly with hindsight."} |
| brain | 1 | SessionStart | {} |
| resilience | 10 | — | {} |
| orchestration | 4 | UserPromptSubmit | {} |
| candor | 2 | SessionStart | {"gate.sh": "Automatic candor transcript gating is unavailable. Before finalizing, use the candor skill to verify claims, unresolved risks, and omissions against actual evidence."} |
| lean | 1 | PostToolUse | {} |
| frontend-suite | 1 | — | {} |
| craft-suite | 1 | — | {} |
| php-suite | 1 | — | {} |
| quality-suite | 1 | — | {} |
| quality-principles-suite | 1 | — | {} |
| process-suite | 1 | — | {} |
| taskmaster-suite | 1 | — | {} |
| always-on-suite | 1 | — | {} |
| skill-router | 1 | SessionStart, UserPromptSubmit | {"prime.sh": "Claude sibling-cache discovery is replaced by guidance to inspect Codex’s available skills catalog.", "route-prompt.sh": "Claude command catalog discovery is replaced by native prompt guidance to select a relevant available Codex skill.", "route.sh": "Automatic file-signal routing requires Claude cache discovery; consult available skill descriptions when changing a new surface.", "summary.sh": "Claude routing-ledger summaries are unavailable because native routing is skill-driven rather than inferred from tool events."} |
| command-guard | 2 | PreToolUse | {} |
| secret-scanning | 2 | PreToolUse | {} |
| payments | 2 | — | {} |
| llm-app | 2 | — | {} |
| ultra-deep-research | 2 | — | {} |
| fresh-take | 1 | UserPromptSubmit | {} |
| terse | 8 | SessionStart, UserPromptSubmit | {} |
| design-lab | 2 | — | {} |
