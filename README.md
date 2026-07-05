# cc-plugins-marketplace: Claude Code Plugin Marketplace

cc-plugins-marketplace is a self-hosted marketplace of best-practice plugins for Claude Code. Each plugin bundles skills, commands, and agents that enforce code quality standards across your projects—from React and Vue to Laravel and beyond.

## Installation

To add the cc-plugins-marketplace marketplace to your Claude Code config:

```bash
/plugin marketplace add <git-url-or-local-path>
```

Then install individual plugins:

```bash
/plugin install <plugin>@cc-plugins-marketplace
```

For example:

```bash
/plugin install react@cc-plugins-marketplace
/plugin install laravel@cc-plugins-marketplace
/plugin install code-architecture@cc-plugins-marketplace
```

## Plugins

| Plugin | Description | Commands |
|--------|-------------|----------|
| **ui-ux** | UI/UX best practices: shadcn/ui, Tailwind, CSS3, Bootstrap, CSS Grid, Flexbox + ui-ux-reviewer agent | `/ui-ux:review` |
| **react** | React: hooks, render/memo, state management, patterns | `/react:review` |
| **react-native** | React Native: list performance, navigation, platform code, animations | `/react-native:review` |
| **vue2** | Vue 2.7: Composition API, reactivity, migration readiness | `/vue2:review` |
| **vue3** | Vue 3: script setup, composables, ref/reactive, Pinia | `/vue3:review` |
| **laravel** | Laravel: Eloquent N+1, form requests, service layer, queues, policies | `/laravel:review` |
| **livewire** | Livewire 3: components, wire:model, performance, Alpine interop | `/livewire:review` |
| **code-architecture** | Engineering process: plan-before-code, YAGNI, task orchestration, work verification, low-cognitive-load, KISS/DRY simplicity + architecture-reviewer agent | `/code-architecture:plan`, `/code-architecture:verify`, `/code-architecture:yagni` |
| **design-patterns** | Design patterns: selection, fitting, anti-patterns | `/design-patterns:suggest` |
| **api-docs-first** | API-docs-first: verify docs before writing integration code | `/api-docs-first:check` |

## Usage

Skills auto-trigger based on context (e.g., `react-best-practices` activates when writing React code). Commands like `/react:review` are invoked manually. You can also invoke them from the command line or via the plugin menu.

## Contributing

To add a new plugin:

1. Create a directory: `plugins/<name>/.claude-plugin/`
2. Add a `plugin.json` manifest (see existing plugins for examples)
3. Update `.claude-plugin/marketplace.json` with your plugin entry
4. Run `bash scripts/validate.sh` to verify the structure

All plugins are versioned at `0.1.0` and owned by Ivan-WG <dev@intername.media>.
