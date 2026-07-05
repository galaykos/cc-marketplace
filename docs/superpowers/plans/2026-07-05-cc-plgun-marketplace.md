# cc-plgun Marketplace Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a self-hosted Claude Code plugin marketplace (git monorepo) with 10 best-practice plugins covering UI/UX stacks, frameworks, and engineering process.

**Architecture:** One repo = one marketplace. `.claude-plugin/marketplace.json` lists 10 plugins living under `plugins/<name>/`. Each plugin ships auto-triggering skills, manual slash commands, and (where specified) agents and hooks. A `scripts/validate.sh` lint gates every task.

**Tech Stack:** Markdown + YAML frontmatter, JSON manifests, POSIX shell (validation + hook), `jq` for JSON checks.

## Global Constraints

- Plugin manifest path: `plugins/<name>/.claude-plugin/plugin.json`, version `0.1.0` for all plugins.
- Marketplace name: `cc-plgun`. Owner: `Ivan-WG <dev@intername.media>`.
- Skill frontmatter: exactly `name` and `description` keys. Description must contain trigger phrases ("Use when ...").
- Skill body budget: 100–150 lines. Distilled practices + short code examples + final section `## Verify Against Current Docs` with official doc URLs.
- Commands are namespaced automatically: `/<plugin>:<command-file-basename>`.
- Hook scripts must fail open: any error → print nothing, exit 0.
- Every task ends with `bash scripts/validate.sh` passing and a git commit.
- Write all content in normal professional English (no caveman compression inside deliverables).
- Framework review command template — every framework plugin's `commands/review.md` uses exactly this shape, substituting `<plugin>` and `<skill>`:

```markdown
---
description: Review <plugin> code against <skill>
---

Review the code in $ARGUMENTS (or the current diff if no argument) against the
<skill> skill from this plugin. Invoke the skill first. Report findings as
`path:line — problem — fix`, ordered by severity. Skip formatting nits unless
they change behavior.
```

---

### Task 1: Marketplace scaffold + validator

**Files:**
- Create: `.claude-plugin/marketplace.json`
- Create: `plugins/<name>/.claude-plugin/plugin.json` for all 10 plugins
- Create: `scripts/validate.sh`
- Create: `README.md`

**Interfaces:**
- Produces: repo skeleton all later tasks write into; `scripts/validate.sh` used as the test gate by every later task.

- [ ] **Step 1: Write `.claude-plugin/marketplace.json`**

```json
{
  "name": "cc-plgun",
  "owner": { "name": "Ivan-WG", "email": "dev@intername.media" },
  "metadata": {
    "description": "Self-hosted best-practice plugins: UI/UX stacks, frameworks, architecture, design patterns, API-docs-first workflow.",
    "version": "0.1.0"
  },
  "plugins": [
    { "name": "ui-ux", "source": "./plugins/ui-ux", "description": "UI/UX best practices with per-stack skills: shadcn/ui, Tailwind, CSS3, Bootstrap, CSS Grid, Flexbox. Includes /ui-ux:review and a ui-ux-reviewer agent." },
    { "name": "react", "source": "./plugins/react", "description": "React best practices: hooks rules, render/memo performance, state management, component patterns. Includes /react:review." },
    { "name": "react-native", "source": "./plugins/react-native", "description": "React Native best practices: list performance, navigation, platform-specific code, animations. Includes /react-native:review." },
    { "name": "vue2", "source": "./plugins/vue2", "description": "Vue 2.7 best practices: Composition API backport, defineProperty reactivity caveats, Vue 3 migration readiness. Includes /vue2:review." },
    { "name": "vue3", "source": "./plugins/vue3", "description": "Vue 3 best practices: script setup, composables, ref/reactive pitfalls, Pinia. Includes /vue3:review." },
    { "name": "laravel", "source": "./plugins/laravel", "description": "Laravel best practices: Eloquent N+1 prevention, form requests, service layer, queues, policies. Includes /laravel:review." },
    { "name": "livewire", "source": "./plugins/livewire", "description": "Livewire 3 best practices: component conventions, wire:model modifiers, performance, Alpine interop. Includes /livewire:review." },
    { "name": "code-architecture", "source": "./plugins/code-architecture", "description": "Engineering process: plan-before-code, YAGNI checks, task orchestration, work verification, low-cognitive-load code. Includes /code-architecture:plan|verify|yagni and an architecture-reviewer agent." },
    { "name": "design-patterns", "source": "./plugins/design-patterns", "description": "Design pattern selection: which pattern fits where, and when NOT to use one. Includes /design-patterns:suggest." },
    { "name": "api-docs-first", "source": "./plugins/api-docs-first", "description": "Verify current API docs before writing integration code; asks for a URL or file when docs are not visible. Includes /api-docs-first:check and a UserPromptSubmit reminder hook." }
  ]
}
```

- [ ] **Step 2: Generate the 10 plugin.json manifests**

```bash
cd /Users/ivangalayko/Programming/Personal/git-repositories/cc-plgun
names=(ui-ux react react-native vue2 vue3 laravel livewire code-architecture design-patterns api-docs-first)
descs=(
  "UI/UX best practices with per-stack skills: shadcn/ui, Tailwind, CSS3, Bootstrap, CSS Grid, Flexbox."
  "React best practices: hooks rules, render/memo performance, state management, component patterns."
  "React Native best practices: list performance, navigation, platform-specific code, animations."
  "Vue 2.7 best practices: Composition API backport, reactivity caveats, migration readiness."
  "Vue 3 best practices: script setup, composables, ref/reactive pitfalls, Pinia."
  "Laravel best practices: Eloquent N+1 prevention, form requests, service layer, queues, policies."
  "Livewire 3 best practices: component conventions, wire:model modifiers, performance, Alpine interop."
  "Engineering process: plan-before-code, YAGNI, task orchestration, work verification, low-cognitive-load code."
  "Design pattern selection: which pattern fits where, and when NOT to use one."
  "Verify current API docs before writing integration code; ask for a URL or file when docs are missing."
)
for i in "${!names[@]}"; do
  mkdir -p "plugins/${names[$i]}/.claude-plugin"
  cat > "plugins/${names[$i]}/.claude-plugin/plugin.json" <<EOF
{
  "name": "${names[$i]}",
  "version": "0.1.0",
  "description": "${descs[$i]}",
  "author": { "name": "Ivan-WG", "email": "dev@intername.media" }
}
EOF
done
```

- [ ] **Step 3: Write `scripts/validate.sh`**

```bash
#!/usr/bin/env bash
# Validates cc-plgun marketplace structure. Exits non-zero on first category of failure.
set -u
cd "$(dirname "$0")/.."
fail=0
err() { echo "FAIL: $1" >&2; fail=1; }

command -v jq >/dev/null 2>&1 || { echo "FAIL: jq is required" >&2; exit 1; }

MP=.claude-plugin/marketplace.json
[ -f "$MP" ] || { echo "FAIL: $MP missing" >&2; exit 1; }
jq empty "$MP" 2>/dev/null || { echo "FAIL: $MP is not valid JSON" >&2; exit 1; }

# Every marketplace entry must resolve to a directory with a valid plugin.json
while IFS=$'\t' read -r name source; do
  dir="${source#./}"
  [ -d "$dir" ] || { err "plugin '$name': directory $dir missing"; continue; }
  pj="$dir/.claude-plugin/plugin.json"
  [ -f "$pj" ] || { err "plugin '$name': $pj missing"; continue; }
  jq empty "$pj" 2>/dev/null || { err "plugin '$name': $pj invalid JSON"; continue; }
  jname=$(jq -r .name "$pj")
  [ "$jname" = "$name" ] || err "plugin '$name': plugin.json name is '$jname'"
done < <(jq -r '.plugins[] | [.name, .source] | @tsv' "$MP")

# Every plugin directory must be listed in the marketplace
for dir in plugins/*/; do
  name=$(basename "$dir")
  jq -e --arg n "$name" '.plugins[] | select(.name == $n)' "$MP" >/dev/null \
    || err "directory plugins/$name not listed in marketplace.json"
done

# Every SKILL.md needs frontmatter with name: and description:
while IFS= read -r f; do
  head -1 "$f" | grep -q '^---$' || { err "$f: missing frontmatter opener"; continue; }
  fm=$(awk '/^---$/{c++; next} c==1{print} c==2{exit}' "$f")
  echo "$fm" | grep -q '^name:' || err "$f: frontmatter missing name:"
  echo "$fm" | grep -q '^description:' || err "$f: frontmatter missing description:"
done < <(find plugins -name SKILL.md)

# hooks.json files must parse and referenced scripts must be executable
while IFS= read -r f; do
  jq empty "$f" 2>/dev/null || { err "$f: invalid JSON"; continue; }
  plugroot=$(dirname "$(dirname "$f")")
  while IFS= read -r cmd; do
    script="${cmd/\$\{CLAUDE_PLUGIN_ROOT\}/$plugroot}"
    [ -x "$script" ] || err "$f: hook script $script missing or not executable"
  done < <(jq -r '.. | .command? // empty' "$f" | grep '^\${CLAUDE_PLUGIN_ROOT}')
done < <(find plugins -path '*/hooks/hooks.json')

[ "$fail" -eq 0 ] && echo "OK: marketplace valid" || exit 1
```

- [ ] **Step 4: Make it executable and run it**

Run: `chmod +x scripts/validate.sh && bash scripts/validate.sh`
Expected: `OK: marketplace valid`

- [ ] **Step 5: Write `README.md`**

Content requirements (write fully, ~60 lines): what cc-plgun is; install section with the two commands (`/plugin marketplace add <git-url-or-local-path>`, `/plugin install <plugin>@cc-plgun`); plugin table (10 rows: name, what it provides, commands); note that skills auto-trigger and can be invoked manually; contribution note (add plugin dir + marketplace.json entry, run `scripts/validate.sh`).

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: marketplace scaffold, 10 plugin manifests, validator, README"
```

---

### Task 2: ui-ux plugin

**Files:**
- Create: `plugins/ui-ux/skills/{shadcn,tailwind,css3,bootstrap,css-grid,flexbox}-best-practices/SKILL.md`
- Create: `plugins/ui-ux/commands/review.md`
- Create: `plugins/ui-ux/agents/ui-ux-reviewer.md`

**Interfaces:**
- Consumes: Task 1 scaffold + validator.
- Produces: standalone plugin; no later task depends on it.

- [ ] **Step 1: Write the six SKILL.md files**

Frontmatter (exact, one per skill — substitute per row):

| dir | name | description |
|---|---|---|
| shadcn-best-practices | shadcn-best-practices | Use when building or reviewing UI with shadcn/ui components — installation via CLI, composition over configuration, theming with CSS variables, accessibility defaults. |
| tailwind-best-practices | tailwind-best-practices | Use when writing or reviewing Tailwind CSS — utility ordering, extracting components vs @apply, responsive/dark variants, design tokens via config. |
| css3-best-practices | css3-best-practices | Use when writing or reviewing plain CSS3 — custom properties, cascade layers, logical properties, container queries, specificity management. |
| bootstrap-best-practices | bootstrap-best-practices | Use when building or reviewing Bootstrap 5 UI — grid system, utility API, Sass customization over overrides, component accessibility. |
| css-grid-best-practices | css-grid-best-practices | Use when building two-dimensional layouts with CSS Grid — template areas, auto-fit/auto-fill, minmax, subgrid, when Grid over Flexbox. |
| flexbox-best-practices | flexbox-best-practices | Use when building one-dimensional layouts with Flexbox — main/cross axis control, flex shorthand pitfalls, gap, wrapping, when Flexbox over Grid. |

Body per skill (100–150 lines each): 5–8 opinionated practice sections with a short good/bad code example each; a "common mistakes" list; final `## Verify Against Current Docs` section linking official docs (ui.shadcn.com, tailwindcss.com/docs, developer.mozilla.org CSS, getbootstrap.com/docs, MDN Grid, MDN Flexbox) with instruction: version-sensitive APIs → check current docs before relying on memory.

- [ ] **Step 2: Write `commands/review.md`**

```markdown
---
description: Review UI code against the relevant stack's best-practice skill (shadcn, Tailwind, CSS3, Bootstrap, Grid, Flexbox)
---

Review the UI code in $ARGUMENTS (or the current diff if no argument) against the
ui-ux plugin skills. Steps:

1. Detect which stacks the code uses (shadcn/ui, Tailwind, plain CSS3, Bootstrap, Grid, Flexbox).
2. Invoke the matching *-best-practices skill(s) from this plugin.
3. Report findings as `path:line — problem — fix`, ordered by severity.
4. Do not report formatting nits unless they change rendering behavior.
```

- [ ] **Step 3: Write `agents/ui-ux-reviewer.md`**

```markdown
---
name: ui-ux-reviewer
description: Use PROACTIVELY after writing or modifying UI components/styles. Reviews markup and styles against shadcn/Tailwind/CSS3/Bootstrap/Grid/Flexbox best practices and accessibility basics.
tools: Read, Grep, Glob
---

You are a UI/UX reviewer. Given files or a diff:

1. Identify the styling stack(s) in use.
2. Check against the corresponding ui-ux plugin skill guidance: semantics, accessibility
   (labels, contrast, focus states, keyboard reachability), responsive behavior,
   idiomatic use of the stack (no fighting the framework), and layout-tool fit
   (Grid for 2D, Flexbox for 1D).
3. Output one line per finding: `path:line — severity — problem — fix`.
4. No praise, no scope creep, no formatting nits.
```

- [ ] **Step 4: Validate and commit**

Run: `bash scripts/validate.sh` — Expected: `OK: marketplace valid`

```bash
git add plugins/ui-ux && git commit -m "feat(ui-ux): six per-stack skills, review command, reviewer agent"
```

---

### Task 3: react plugin

**Files:**
- Create: `plugins/react/skills/react-best-practices/SKILL.md`
- Create: `plugins/react/commands/review.md`

**Interfaces:** Consumes Task 1. Standalone.

- [ ] **Step 1: SKILL.md** — frontmatter name `react-best-practices`, description: `Use when writing or reviewing React code — hooks rules and dependencies, avoiding unnecessary re-renders, state colocation and lifting, component composition patterns, effect misuse.` Body sections: rules of hooks + exhaustive deps; derive-don't-sync state (no redundant useEffect); memoization (when useMemo/useCallback/memo help and when they are noise); state colocation / lifting / context boundaries; controlled vs uncontrolled; composition over prop drilling; keys and list identity; common mistakes list; `## Verify Against Current Docs` → react.dev.
- [ ] **Step 2: commands/review.md** — description `Review React code against react-best-practices`; body: invoke the skill, review `$ARGUMENTS` or current diff, findings as `path:line — problem — fix`.
- [ ] **Step 3: Validate + commit** — `bash scripts/validate.sh` OK, then `git add plugins/react && git commit -m "feat(react): best-practices skill and review command"`.

---

### Task 4: react-native plugin

**Files:**
- Create: `plugins/react-native/skills/react-native-best-practices/SKILL.md`
- Create: `plugins/react-native/commands/review.md`

Same shape as Task 3. Skill description: `Use when writing or reviewing React Native code — FlatList/FlashList performance, navigation patterns, platform-specific code, native driver animations, image handling.` Body sections: list virtualization (keyExtractor, getItemLayout, avoid anonymous renderItem); React Navigation structure; Platform.select and .ios/.android files; Animated/Reanimated with native driver; image sizing/caching; bridge-crossing minimization; StyleSheet.create; common mistakes; docs → reactnative.dev. Command: use the framework review command template from Global Constraints with <plugin>=react-native, <skill>=react-native-best-practices. Validate + commit `feat(react-native): ...`.

---

### Task 5: vue2 plugin

**Files:**
- Create: `plugins/vue2/skills/vue2-best-practices/SKILL.md`
- Create: `plugins/vue2/commands/review.md`

Skill description: `Use when writing or reviewing Vue 2.7 code — Composition API backport usage, defineProperty reactivity caveats (array index/object property assignment), Vue.set, mixins vs composables, Vue 3 migration readiness.` Body sections: prefer 2.7 Composition API composables over mixins; reactivity caveats: `this.obj.newProp = x` and `arr[i] = x` are NOT reactive → `Vue.set`/replace; `.sync` and `$listeners` patterns; filters deprecated → methods/computed; write forward-compatible code for Vue 3 migration; common mistakes; docs → v2.vuejs.org. Command: framework review template, <plugin>=vue2, <skill>=vue2-best-practices. Validate + commit `feat(vue2): ...`.

---

### Task 6: vue3 plugin

**Files:**
- Create: `plugins/vue3/skills/vue3-best-practices/SKILL.md`
- Create: `plugins/vue3/commands/review.md`

Skill description: `Use when writing or reviewing Vue 3 code — script setup, composables design, ref vs reactive pitfalls, destructuring reactivity loss, watch vs watchEffect, Pinia stores.` Body sections: `<script setup>` as default; ref vs reactive (prefer ref; reactive loses reactivity on destructure — use toRefs); composable conventions (`useX`, return refs); props destructure caveat / `defineProps`; watch vs watchEffect vs computed; Pinia over Vuex, store shape; provide/inject typing; common mistakes; docs → vuejs.org + pinia.vuejs.org. Command: framework review template, <plugin>=vue3, <skill>=vue3-best-practices. Validate + commit `feat(vue3): ...`.

---

### Task 7: laravel plugin

**Files:**
- Create: `plugins/laravel/skills/laravel-best-practices/SKILL.md`
- Create: `plugins/laravel/commands/review.md`

Skill description: `Use when writing or reviewing Laravel code — Eloquent N+1 prevention and eager loading, form request validation, thin controllers with service/action classes, queued jobs, authorization policies, migrations.` Body sections: N+1 → `with()`, `loadMissing()`, `Model::preventLazyLoading()` in dev; validation in FormRequest not controller; thin controllers → actions/services; policies + gates for authz; queue slow work, idempotent jobs; config/env discipline (`config()` not `env()` outside config files); migrations irreversibility awareness; common mistakes; docs → laravel.com/docs. Command: framework review template, <plugin>=laravel, <skill>=laravel-best-practices. Validate + commit `feat(laravel): ...`.

---

### Task 8: livewire plugin

**Files:**
- Create: `plugins/livewire/skills/livewire-best-practices/SKILL.md`
- Create: `plugins/livewire/commands/review.md`

Skill description: `Use when writing or reviewing Livewire 3 code — component granularity, wire:model live/blur/debounce modifiers, computed properties, locked properties, pagination, Alpine interop.` Body sections: Livewire 3 defaults (deferred model binding — opt into `.live` deliberately); `#[Computed]` for derived data; `#[Locked]` for ids the client must not tamper with; keep components small, `wire:key` in loops; pagination trait; events between components vs parent props; Alpine for pure client-side state, `$wire` bridge; common mistakes; docs → livewire.laravel.com. Command: framework review template, <plugin>=livewire, <skill>=livewire-best-practices. Validate + commit `feat(livewire): ...`.

---

### Task 9: code-architecture plugin

**Files:**
- Create: `plugins/code-architecture/skills/{plan-before-code,yagni-check,task-orchestration,work-verification,low-cognitive-load}/SKILL.md`
- Create: `plugins/code-architecture/commands/{plan,verify,yagni}.md`
- Create: `plugins/code-architecture/agents/architecture-reviewer.md`

- [ ] **Step 1: Five SKILL.md files.** Frontmatter table:

| dir | description |
|---|---|
| plan-before-code | Use before writing any non-trivial code — decide which files change, what each new unit owns, interfaces between units, and where code should live, before writing it. |
| yagni-check | Use when designing or reviewing code for speculative generality — flags abstractions, config options, and flexibility nobody asked for. |
| task-orchestration | Use when breaking work into tasks or delegating to subagents — decomposition into independently verifiable units, sequencing by dependency, parallelizing independent work. |
| work-verification | Use before claiming any work is done — define success criteria up front, run the verification commands, show evidence, never assert without output. |
| low-cognitive-load | Use when writing or reviewing code for readability — small focused units, few live variables, shallow nesting, names that carry meaning, no clever tricks. |

Bodies (100–150 lines each): concrete procedure/checklist + short before/after examples. plan-before-code: file-map-first procedure (list files to touch, one responsibility per file, define interfaces, then code). yagni-check: red-flag list (unused params "for later", single-implementation interfaces, config nobody sets, premature plugin systems) + "delete until it hurts" test. task-orchestration: task = smallest independently verifiable unit; dependency ordering; parallel dispatch criteria (no shared state); review gates between tasks. work-verification: criteria-before-work; evidence-before-assertion; exact-command + expected-output discipline. low-cognitive-load: function-fits-on-screen rule, guard clauses over nesting, avoid boolean params, locality of behavior.

- [ ] **Step 2: Three commands.** `plan.md`: description `Produce a file-level implementation plan before writing code`; body: invoke plan-before-code skill on `$ARGUMENTS`, output file map + interfaces + task sequence, do not write code. `verify.md`: description `Verify completed work against its success criteria with evidence`; body: invoke work-verification, run the project's test/lint commands, report pass/fail with output. `yagni.md`: description `Audit code or a design for speculative generality`; body: invoke yagni-check on `$ARGUMENTS` or diff, list violations with deletion proposals.

- [ ] **Step 3: `agents/architecture-reviewer.md`**

```markdown
---
name: architecture-reviewer
description: Use PROACTIVELY after structural changes, new modules, or API changes. Reviews boundaries, dependencies, and cohesion; flags YAGNI violations and high-cognitive-load code.
tools: Read, Grep, Glob
---

You are an architecture reviewer. Given a diff or module:

1. Map the units touched and their dependency direction.
2. Check: single responsibility per unit, dependencies point toward stable
   abstractions, no cycles, interfaces small and consumer-driven.
3. Flag speculative generality (YAGNI) and unnecessarily clever code.
4. Output one line per finding: `path:line — severity — problem — fix`.
   No praise. No restating the diff.
```

- [ ] **Step 4: Validate + commit** — `bash scripts/validate.sh` OK; `git add plugins/code-architecture && git commit -m "feat(code-architecture): five process skills, three commands, reviewer agent"`.

---

### Task 10: design-patterns plugin

**Files:**
- Create: `plugins/design-patterns/skills/pattern-selection/SKILL.md`
- Create: `plugins/design-patterns/commands/suggest.md`

- [ ] **Step 1: SKILL.md** — name `pattern-selection`, description: `Use when structuring code and considering a design pattern — maps problems to patterns (creational, structural, behavioral), and lists when NOT to use each; simplest-thing-first.` Body: problem→pattern table (object creation variants → Factory/Builder; incompatible interface → Adapter; behavior swap at runtime → Strategy; react to events → Observer; expensive object graph → Prototype/Flyweight rarely; cross-cutting wrap → Decorator; sequential processing with bail-out → Chain of Responsibility; undo/queueable operations → Command; single shared resource → module/DI over Singleton); anti-pattern section: pattern-for-pattern's-sake, Singleton-as-global, inheritance where composition fits; rule: name the problem first, pattern second; language-idiom note (closures/first-class functions replace many GoF patterns); docs pointer → refactoring.guru/design-patterns as reference catalog.
- [ ] **Step 2: commands/suggest.md** — description `Suggest (or reject) a design pattern for a described problem`; body: invoke pattern-selection on `$ARGUMENTS`, respond with: restated problem, simplest non-pattern solution, pattern recommendation only if it beats the simple solution, trade-offs.
- [ ] **Step 3: Validate + commit** — `feat(design-patterns): pattern-selection skill and suggest command`.

---

### Task 11: api-docs-first plugin

**Files:**
- Create: `plugins/api-docs-first/skills/api-docs-first/SKILL.md`
- Create: `plugins/api-docs-first/commands/check.md`
- Create: `plugins/api-docs-first/hooks/hooks.json`
- Create: `plugins/api-docs-first/hooks/remind.sh` (executable)

- [ ] **Step 1: SKILL.md** — name `api-docs-first`, description: `Use before writing any code that calls an external API, SDK, or third-party library — verify current official docs first; if docs are not accessible, stop and ask the user for a docs URL or file. Never code an integration from memory alone.` Body: procedure — (1) identify exact library/API + version from lockfile/manifest; (2) locate current official docs (WebFetch/WebSearch if available, local docs dirs, vendored README); (3) verify the specific endpoints/methods/params you are about to use; (4) if no docs reachable → ask user for URL or file path, do not proceed on memory; (5) note version-sensitive areas (auth flows, pagination, deprecations). Includes "signals you are coding from stale memory" list (guessing param names, copying pre-cutoff snippets, version mismatch with lockfile).

- [ ] **Step 2: `hooks/hooks.json`**

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/remind.sh" }
        ]
      }
    ]
  }
}
```

- [ ] **Step 3: `hooks/remind.sh`**

```bash
#!/usr/bin/env bash
# Fail open: never block the prompt. Print a reminder only on keyword match.
{
  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  if printf '%s' "$prompt" | grep -qiE '\b(api|sdk|endpoint|integrat|webhook|oauth|rest|graphql)\b'; then
    echo "api-docs-first: this prompt mentions an API/SDK integration. Verify current official docs before writing integration code; if no docs are accessible, ask the user for a URL or file (see api-docs-first skill)."
  fi
} 2>/dev/null
exit 0
```

Run: `chmod +x plugins/api-docs-first/hooks/remind.sh`

- [ ] **Step 4: `commands/check.md`** — description `Check that current API docs back the integration code you are about to write or review`; body: invoke api-docs-first skill for `$ARGUMENTS` (library or API name), report: exact version from lockfile, docs source found (URL/file), verified symbols, or a request to the user for docs.

- [ ] **Step 5: Test hook manually**

Run: `echo '{"prompt":"integrate stripe api"}' | bash plugins/api-docs-first/hooks/remind.sh`
Expected: the reminder line.
Run: `echo '{"prompt":"rename a variable"}' | bash plugins/api-docs-first/hooks/remind.sh`
Expected: no output, exit 0.

- [ ] **Step 6: Validate + commit** — `bash scripts/validate.sh` OK; `git add plugins/api-docs-first && git commit -m "feat(api-docs-first): skill, check command, prompt-submit reminder hook"`.

---

### Task 12: Final validation + smoke test

- [ ] **Step 1:** `bash scripts/validate.sh` → `OK: marketplace valid`.
- [ ] **Step 2:** `claude plugin validate . 2>/dev/null || echo "CLI validator unavailable — validate.sh is the gate"` — record result.
- [ ] **Step 3:** Count check: `find plugins -name SKILL.md | wc -l` → expected 19; `find plugins -path '*/commands/*.md' | wc -l` → expected 12; agents → 2; hooks.json → 1.
- [ ] **Step 4:** Commit any remaining changes: `git add -A && git commit -m "chore: final validation pass"` (skip if clean).
