// Codex schema constants — the ONLY place a Codex-specific field name, path, or
// enum value may appear in scripts/gen-codex/. Every transform imports from here so
// that schema churn (Codex plugin/marketplace is ~Mar 2026 and evolving) touches one
// file. Verified live against learn.chatgpt.com/docs (developers.openai.com/codex/*
// 308-redirects there) on 2026-07-10. Re-verify before a build if Codex has moved.

// Deterministic build stamp (D13). NOT a timestamp — a timestamp would break the
// byte-identical idempotency the freshness gate depends on (SC-2). Bump this by hand
// when the Codex schema constants below change, so a within-plugin-version manifest
// regeneration is still visible to a Codex consumer.
export const SCHEMA_VERSION = '2026-07-10'

// ---------------------------------------------------------------------------
// Per-plugin manifest: .codex-plugin/plugin.json
// source: https://learn.chatgpt.com/docs/build-plugins (verified 2026-07-10):
//   "Required fields: name, version, description. Optional: author, homepage,
//    repository, license, keywords, skills, mcpServers, apps, hooks, interface."
// Bundles skills + mcpServers + apps + hooks — NOT commands or subagents.
export const PLUGIN_MANIFEST = {
  dir: '.codex-plugin',
  file: '.codex-plugin/plugin.json',
  required: ['name', 'version', 'description'],
  optional: ['author', 'homepage', 'repository', 'license', 'keywords', 'skills', 'mcpServers', 'apps', 'hooks', 'interface'],
  // interface{} sub-object (install-surface presentation)
  interface: {
    display: ['displayName', 'shortDescription', 'longDescription'],
    metadata: ['developerName', 'category', 'capabilities'],
    links: ['websiteURL', 'privacyPolicyURL', 'termsOfServiceURL'],
    presentation: ['defaultPrompt', 'brandColor', 'composerIcon', 'logo', 'screenshots'],
  },
  // component pointers name the surfaces the plugin bundles (paths/globs resolved by the generator)
  componentPointers: ['skills', 'mcpServers', 'apps', 'hooks'],
}

// ---------------------------------------------------------------------------
// Marketplace catalog: .agents/plugins/marketplace.json
// source: https://learn.chatgpt.com/docs/build-plugins + CORRECTED against codex-cli
//   0.143.0 (verified 2026-07-10): "Repo: $REPO_ROOT/.agents/plugins/marketplace.json."
//   Entry: { name, source:{source:"local", path:"./codex/<name>"}, policy:{installation,
//   authentication}, category, interface{displayName} }. The source DISCRIMINATOR field is
//   literally `source` (value "local" for a path source), `path` needs a `./` prefix and
//   resolves inside the marketplace root; policy + category are required. Dependency-only
//   bundles are OMITTED (a sourceless entry is rejected by the CLI).
export const MARKETPLACE = {
  repoPath: '.agents/plugins/marketplace.json',
  userPath: '~/.agents/plugins/marketplace.json',
  entry: {
    required: ['name', 'source', 'policy', 'category'],
    source: { discriminator: 'source', localValue: 'local', path: 'path' }, // {source:"local", path:"./..."}
    policy: { installation: 'AVAILABLE', authentication: 'ON_INSTALL' },
    optional: ['interface'],
    interface: ['displayName'],
  },
}

// ---------------------------------------------------------------------------
// Skills discovery + skill-id/dir charset
// source: https://learn.chatgpt.com/docs/build-skills (verified 2026-07-10):
//   "Repository level: $CWD/.agents/skills ... User level: $HOME/.agents/skills."
//   "The SKILL.md file must include name and description." Example id uses
//   lowercase-hyphen: `skill-name`. No explicit charset restriction documented;
//   hyphenated-lowercase is the documented form, so keeping this repo's original
//   (globally-unique, already lowercase-hyphen) skill basenames is safe. Underscores
//   are NOT documented as allowed — do not introduce them (the generator keeps
//   original basenames rather than a `<plugin>__<skill>` scheme).
export const SKILL_DIR = {
  repoRoot: '.agents/skills',
  userRoot: '~/.agents/skills',
  frontmatterRequired: ['name', 'description'],
  // conservative safe charset for a generated skill dir/name (matches documented example + CC's own rule)
  idCharset: /^[a-z0-9]+(?:-[a-z0-9]+)*$/,
  underscoresConfirmedAllowed: false,
}

// ---------------------------------------------------------------------------
// Subagent TOML: ~/.codex/agents/<name>.toml
// source: https://learn.chatgpt.com/docs/agent-configuration/subagents (verified 2026-07-10):
//   Required: name, description, developer_instructions. Optional: nickname_candidates,
//   model, model_reasoning_effort, sandbox_mode, mcp_servers, skills.config.
//   model_reasoning_effort allowed values: "ultra","max","xhigh","high","medium",
//   "low","minimal","none". sandbox_mode: "read-only","workspace-write" (+ danger-full-access).
export const AGENT_TOML = {
  home: '~/.codex/agents',
  required: ['name', 'description', 'developer_instructions'],
  optional: ['nickname_candidates', 'model', 'model_reasoning_effort', 'sandbox_mode', 'mcp_servers', 'skills.config'],
  reasoningEffortEnum: ['ultra', 'max', 'xhigh', 'high', 'medium', 'low', 'minimal', 'none'],
  sandboxModes: ['read-only', 'workspace-write', 'danger-full-access'],
  // The generator OMITS `model` (CC slugs opus/sonnet are not valid Codex model ids);
  // the agent inherits the Codex session model. See card 06.
  omitModel: true,
}

// ---------------------------------------------------------------------------
// CC effort -> Codex model_reasoning_effort.
// DELTA from spec assumption: Codex's enum is a SUPERSET of CC's — both `xhigh`
// and `max` exist (plus `ultra`,`minimal`,`none`). So the map is identity; no clamp
// is required. (The spec/red-team assumed `xhigh`/`max` might not exist — live docs
// confirm they do.) Kept explicit so any future enum divergence is a one-line change.
// source: https://learn.chatgpt.com/docs/agent-configuration/subagents (verified 2026-07-10).
export const EFFORT_MAP = {
  low: 'low',
  medium: 'medium',
  high: 'high',
  xhigh: 'xhigh',
  max: 'max',
}

// ---------------------------------------------------------------------------
// CC hook tool-name -> Codex matcher tool-name (for PreToolUse/PostToolUse `matcher`).
// source: https://learn.chatgpt.com/docs/hooks (verified 2026-07-10):
//   "For file edits through apply_patch, matcher values can use apply_patch, Edit,
//    or Write; hook input still reports tool_name: apply_patch." Also `Bash` for shell,
//    and MCP tools as `mcp__<server>__<tool>`.
// So CC's Edit|Write are valid Codex matchers as-is (aliases for apply_patch), and
// MultiEdit maps to apply_patch. A CC tool with no Codex peer maps to null => the
// matcher references a dropped surface (recorded, fail-open).
export const TOOL_MATCHER_MAP = {
  Edit: 'Edit',
  Write: 'Write',
  MultiEdit: 'apply_patch',
  Bash: 'Bash',
  Read: null, // no documented Codex Read matcher; hooks matching Read degrade to dropped
}

// ---------------------------------------------------------------------------
// Does `codex plugin marketplace add owner/repo` resolve a raw GitHub repo without
// the (not-yet-open) official directory? YES.
// source: https://learn.chatgpt.com/docs/build-plugins (verified 2026-07-10):
//   "codex plugin marketplace add owner/repo accepts GitHub shorthand without
//    requiring official directory publishing" (also supports --ref main).
// => The end-to-end install claim (SC-9) is achievable now, not deferred.
export const MARKETPLACE_ADD_FROM_REPO = true

// ---------------------------------------------------------------------------
// Codex hook event names.
// source: https://learn.chatgpt.com/docs/hooks (verified 2026-07-10):
//   SessionStart, SubagentStart, PreToolUse, PermissionRequest, PostToolUse,
//   PreCompact, PostCompact, UserPromptSubmit, SubagentStop, Stop. NO SessionEnd.
export const HOOK_EVENTS = [
  'SessionStart',
  'SubagentStart',
  'PreToolUse',
  'PermissionRequest',
  'PostToolUse',
  'PreCompact',
  'PostCompact',
  'UserPromptSubmit',
  'SubagentStop',
  'Stop',
]
// CC events the generator must handle: SessionStart/UserPromptSubmit/PostToolUse are
// kept; SessionEnd has NO Codex equivalent and is dropped (card 07).
export const CC_HOOK_EVENT_SUPPORTED = {
  SessionStart: 'SessionStart',
  UserPromptSubmit: 'UserPromptSubmit',
  PostToolUse: 'PostToolUse',
  SessionEnd: null, // dropped — no Codex peer
}
