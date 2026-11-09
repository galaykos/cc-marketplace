# unreal: derivations and sources (2026-11-09)

Written on 2026-11-09, when `plugins/unreal` 0.2.0 added its first script and the pointer to Epic's own agent
tooling. Every fact below was read that day from the URL given beside it. Standing: `recorded` — no gate reads this
file.

## plugins/unreal/scripts/check_unreal_project.py

### Why it exists

The skill's rule "CI and team machines keep zenserver alive" sat at `recorded` with nothing reading
`DefaultEngine.ini`. 5.8 also renamed a Zen key, and Epic's own 5.8 Zen Streaming page still shows the old one.
Deprecated C++ names compile with a warning that scrolls past, so a model writing from memory keeps them. A
version-windowed lexical check with an exit code is the one artifact here that prose cannot replace.

### Design

- Version: `--engine-version`, else `EngineAssociation` when it reads `X.Y[.Z]`. A GUID or empty value (source
  build) exits 2 and asks for `--engine-version`. The checker does not read `Engine/Build/Build.version`: its field
  layout was not verified from an Epic page this run.
- Source rules: one regex per rule over `Source/**/*.cpp|h`, after comments, string, raw-string and char literals
  are blanked. Digit separators (`1'000`) are not mistaken for char literals. Each rule carries `deprecated`
  (warning from that version) and `removed` (error from that version), the blender `check_bpy_scripts.py` idiom.
- Config rules apply from 5.8 only, over `Config/**/*.ini` (`;` comments skipped, UE's `+-.!@*` key prefixes
  accepted). `zen-process-lifetime` is skipped when `Config/DefaultGame.ini` sets `bUseZenStore` false in a
  `*ProjectPackagingSettings` section.
- Output, flags and exit codes copy `godot/scripts/check_godot_project.py`. Each finding also carries `source`, its
  URL.

### Rules and their sources

Release-notes URLs take the form
`https://dev.epicgames.com/documentation/en-us/unreal-engine/unreal-engine-<v>-release-notes?application_version=<v>`.
The slug is `5.1` for 5.1 and `5-3`…`5-8` for later versions. Without `application_version`, the older slugs return
the 5.8 page or an empty shell.

| Rule id | Window | Release-note text (verbatim, abridged) |
|---|---|---|
| `any-package` | warn ≥ 5.1 | 5.1: "Deprecated ANY_PACKAGE macro support for looking up UObjects … such as FindObject<UClass>(nullptr, TEXT("/Script/Engine.Actor"))"; "Utility functions like FindFirstObject …" |
| `player-mappable-input-config` | warn ≥ 5.3 | 5.3: "Deprecated UPlayerMappableInputConfig in favor of the new UEnhancedInputUserSettings with 5.3." |
| `player-mappable-key-slot` | warn ≥ 5.3 | 5.3: "Deprecated the FPlayerMappableKeySlot and all its related functions for 5.3 … in favor of UEnhancedInputUserSettings." |
| `template-requires` | warn ≥ 5.5 | 5.5: "Deprecated TEMPLATE_REQUIRES. UE_REQUIRES should be used instead, though the syntax is slightly different" |
| `is-allowed-to-tick` | warn ≥ 5.5 | 5.5: "Deprecated FTickableObjectBase::IsAllowedToTick … redundant with the existing IsTickable function. The new SetTickableTickType function …" |
| `non-instanced-ability` | warn ≥ 5.5 | 5.5: "GAS - Deprecating NonInstanced Gameplay Abilities. We now only support either InstancedPerActor or InstancedPerExecution." |
| `ftext-findtext` | warn ≥ 5.5 | 5.5: "FText::FindText is deprecated … Consider FText::FindTextInLiveTable_Advanced or FText::AsLocalizable_Advanced" |
| `motion-controller-data` | warn 5.5–5.6, error ≥ 5.7 | 5.5 upgrade notes: "Replace usages of GetMotionControllerData with GetMotionControllerState and/or GetHandTrackingState"; 5.7: "Removed GetMotionControllerData and FXRMotionControllerData which were deprecated in 5.5." |
| `fcstring-strncat` | warn ≥ 5.6 | 5.6: "Deprecate FCString::Strncat because it has a different meaning than C++ strncat"; "Add FPlatformString::Strncat … taking SrcLen rather than DestSize" |
| `compute-angular-velocity` | warn ≥ 5.7 | 5.7: "UMovementUtils::ComputeAngularVelocity is now deprecated, callers should use ComputeAngularVelocityDegrees" |
| `input-device-scope` | warn ≥ 5.8 | 5.8: "Deprecation the FInputDeviceScope type … use the new FInputDeviceRegistry"; "Effectively make the FInputDeviceScope no-op unless the UE_USE_LEGACY_INPUT_DEVICE_SCOPE define is set to 1" |
| `game-window-type` | warn ≥ 5.8 | 5.8: "`EWindowType::GameWindow` is now deprecated."; upgrade notes: "use `EWindowType::Normal` instead" |
| `on-post-engine-init` | warn ≥ 5.8 | 5.8: "Deprecated FCoreDelegates::OnPostEngineInit in favor of FCoreDelegates::GetOnPostEngineInit() to fix missing registrations that occur during static initialization." |
| `ren-force-no-reset-loaders` | warn ≥ 5.8 | 5.8: "The UObject::Rename flag REN_ForceNoResetLoaders has been deprecated as UObject::Rename will no longer call ResetLoaders" |
| `editor-key-pressed` | error ≥ 5.8 | 5.8: "Deprecation: Remove deprecated AActor::EditorKeyPressed function." |

Config rules, all from the 5.8 release notes. The section "Zenserver as Cooked Output Store" says Zen as the
cooked output store "is now enabled by default". It also says "projects should set LimitProcessLifetime=false in
the Zen.AutoLaunch section of the DefaultEngine.ini", and "The AllowRemoteNetworkService config key has been
renamed and changed to RemoteNetworkService and doesn't accept true / false" (values `None`, `Unsecured`,
`GeneratedStaticKey`). Under Upgrade Notes › Foundation › Core: "Derived Data Cache graphs are now configured in
the [DerivedDataCacheGraphs] section", "stores … in the [DerivedDataCacheStores] section", and "Deprecated
AsyncPut, KeyLength, and Verify graph nodes. AsyncPut is created automatically. Verify is created based on the
-DDC-Verify command line argument." `bUseZenStore` is a `Config=Game, defaultconfig` property of
`UProjectPackagingSettings`, per
`https://dev.epicgames.com/documentation/en-us/unreal-engine/API/Developer/DeveloperToolSettings/UProjectPackagingSettings?application_version=5.8`.
The `[/Script/UnrealEd.ProjectPackagingSettings]` section name appears in the 5.8 release notes (`bDeduplicateChunks`).

### Epic's own pages disagree, which is why the config rules exist

- `how-to-use-zenserver-streaming-to-play-on-target-in-unreal-engine?application_version=5.8` still shows
  `AllowRemoteNetworkService=true`, the key the 5.8 release notes say was renamed.
- `using-derived-data-cache-in-unreal-engine` reads the same at `application_version=5.7` and `5.8` (the text
  differs only in the title). It still documents `[DerivedDataBackendGraph]`. Neither page says whether 5.8 still reads that
  section, so `ddc-legacy-graph` is a warning that asks the user to read `LogDerivedDataCache`.
- `using-zen-storage-server-as-cooked-output-store-for-unreal-engine?application_version=5.8` still says Zen is
  "not used for cooked output storage by default" as of 5.5.
- The `Type=` node syntax is from the DDC page (`Shared=(Type=FileSystem, …)`). That `KeyLength`, `AsyncPut` and
  `Verify` appear as `Type=` values is inferred from the release note's node names, not shown on a page.

### Candidates read and not shipped

- `FSmartName` family and `PLATFORM_TCHAR_IS_4_BYTES` (5.8 deprecations): no replacement named in the notes.
- `USkeletalMeshComponent::SetAnimClass` (deprecated, listed in both the 5.5 and the 5.6 notes): no replacement named.
- `GetCharacterOwner` (removed from motion warping in 5.8), the AnimSequence overload removals, and
  `UNetConnection::GetConnectionId`: the bare names live on in other classes or overloads, so a name match would
  report correct code.
- `UE_LOG` → `UE_LOGF` ("will eventually be deprecated") and `PLATFORM_*` → `UE_PLATFORM_*` ("Optional
  migration"): neither is deprecated yet.

### Measured on 2026-11-09

- `scripts/__tests__/check_unreal_project.test.sh`: 17 cases, all pass.
- Five seeded faults each failed the suite: comment and string blanking off, the 5.7 removal window dropped, the
  config window moved to 5.7, `bUseZenStore` ignored, and digit-separator handling removed.
- No Unreal Engine install or compiler ran. The fixtures encode the release notes as read, not engine behaviour.

### What it does not catch

- A deprecated name reached through a `using` alias, a macro, or a renamed variable. A same-named method on an
  unrelated class is reported (`IsAllowedToTick`, `::NonInstanced`).
- `Plugins/*/Source`, `*.Build.cs`, `*.Target.cs`, `.inl` and `.hpp` files are not scanned. Ini files outside
  `Config/`, such as `Saved/Config` per-user settings, are not read.
- Rules before 5.1 and any name not in the table. The 5.2 and 5.4 notes were fetched but only searched for names
  already chosen; the 5.5–5.8 notes were searched for deprecations and removals, and only the 5.8 Upgrade Notes
  section was read line by line.

## plugins/unreal/skills/unreal-best-practices/SKILL.md § Epic's Claude Code plugin and the 5.8 editor MCP

- `https://dev.epicgames.com/documentation/en-us/unreal-engine/unreal-mcp-in-unreal-editor?application_version=5.8`
  (391 text lines, read in full) gives the following. The plugin id is `ModelContextProtocol` ("Unreal MCP",
  Experimental), and toolsets come from the `AllToolsets` plugin. Auto Start Server defaults to off; the server binds
  `http://127.0.0.1:8000/mcp` with server name `unreal-mcp`. `ModelContextProtocol.GenerateClientConfig ClaudeCode`
  writes `.mcp.json`. Tool search lists three meta-tools. The transport is HTTP/SSE only, loopback, with "no
  authentication layer". A new `UFUNCTION` needs an editor restart. The page mentions "the `create-toolset` skill
  from the `unreal-mcp` Claude Code plugin" without an install line.
- `EpicGames/unreal-engine-skills-for-claude-code-plugin` @0e27bde2b55c5d3f6948532f4296aaa3654d8f4b (MIT;
  `plugin.json` name `unreal-engine-skills-for-claude-code`, version 3.1.2, author at epicgames.com). Its README,
  the `unreal-mcp` skill, and `references/setup.md` and `operations.md` were read in full. They give the install
  line `/plugin install unreal-engine-skills-for-claude-code@claude-plugins-official`, the
  `EditorPerProjectUserSettings.ini` auto-start snippet, the source-build vs launcher `.mcp.json` location, one
  port per editor, `execute_tool_script` running arbitrary Python, and the advice against
  `--dangerously-skip-permissions`. `skills/create-toolset/SKILL.md` (420 lines) and `skills/unreal-skill/SKILL.md`
  were not read.
- `anthropics/claude-plugins-official` @0412be76f50ab4f4f8abff3753efa9269fbbca5b `marketplace.json` lists
  `unreal-engine-skills-for-claude-code` (author "Epic Games") pinned to the same repo SHA, with its homepage
  set to the Unreal MCP page above.
- The two Epic sources differ on concurrency. The MCP page says calls run serially on the game thread and clients
  "should not issue overlapping Tool calls". The plugin says MCP "accepts concurrent requests", so callers should
  serialize dependent ones. The skill states neither.
