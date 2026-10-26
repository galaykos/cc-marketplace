# Changelog — unreal

Consumer-facing changes only. Newest first.

## 0.1.0 — 2026-10-26

- **First release.** The `unreal-best-practices` skill has three references:
  - packaging and cooking: UE 5.8 Zen Server as the default cooked output store, `ue.projectstore`, `-skipzenstore`, `LimitProcessLifetime=false` for CI, the 5.8 Visual Studio/MSVC/Windows SDK/Xcode minimums, DataValidation before cooking;
  - Enhanced Input: the mapping context in `PawnClientRestart`, rebinding through Enhanced Input User Settings;
  - C++ and AI: headless `Automation RunTest`, `TStrongObjectPtr`/`FGCObject`, Behavior Tree node memory, StateTree coexistence.
- **Standing.** The facts are recorded; each reference says which items were re-read against
  Epic's docs on 2026-10-26. No script ships.
- **Credit and effect.** Adapted from gamedev-skills/awesome-gamedev-agent-skills @184b72b
  (Apache-2.0), prose rewritten. Unmeasured: no eval with a control arm covers it.
