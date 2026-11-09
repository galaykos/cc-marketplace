# Changelog — unreal

Consumer-facing changes only. Newest first.

## 0.2.0 — 2026-11-09

- **New script: `scripts/check_unreal_project.py`.** It reads the engine version from `EngineAssociation` (or `--engine-version` for a source build). On 5.8 it warns on these `Config/*.ini` keys: `[Zen.AutoLaunch] LimitProcessLifetime=false` missing, `AllowRemoteNetworkService` (renamed `RemoteNetworkService`), a `RemoteNetworkService` value other than `None`/`Unsecured`/`GeneratedStaticKey`, a `[DerivedDataBackendGraph]` section, and the deprecated `KeyLength`/`AsyncPut`/`Verify` DDC nodes. It also flags 15 C++ names in `Source/**/*.cpp|h` that Epic's 5.1–5.8 release notes deprecate (warning) or remove (error) for that version, each with its URL. Exit 0/1/2; `--json`, `--strict`.
- **Skill pointer to Epic's tooling.** The skill now points to Epic's Claude Code plugin (`unreal-engine-skills-for-claude-code@claude-plugins-official`) and the Experimental 5.8 Unreal MCP editor plugin. It lists the setup traps their docs give: `AllToolsets`, the server off by default, `.mcp.json` placement, tool search, one port per editor, restart for new tools, and no authentication.
- **Standing.** The checker is a gate where run, and its harness (17 cases) runs in this repo's CI. The pointer is recorded and was read from Epic's pages on 2026-11-09. Unmeasured: no eval with a control arm covers it.

## 0.1.0 — 2026-10-26

- **First release.** The `unreal-best-practices` skill has three references:
  - packaging and cooking: UE 5.8 Zen Server as the default cooked output store, `ue.projectstore`, `-skipzenstore`, `LimitProcessLifetime=false` for CI, the 5.8 Visual Studio/MSVC/Windows SDK/Xcode minimums, DataValidation before cooking;
  - Enhanced Input: the mapping context in `PawnClientRestart`, rebinding through Enhanced Input User Settings;
  - C++ and AI: headless `Automation RunTest`, `TStrongObjectPtr`/`FGCObject`, Behavior Tree node memory, StateTree coexistence.
- **Standing.** The facts are recorded; each reference says which items were re-read against
  Epic's docs on 2026-10-26. No script ships.
- **Credit and effect.** Adapted from gamedev-skills/awesome-gamedev-agent-skills @184b72b
  (Apache-2.0), prose rewritten. Unmeasured: no eval with a control arm covers it.
