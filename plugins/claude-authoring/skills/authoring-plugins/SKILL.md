---
name: authoring-plugins
description: Use when assembling or restructuring a Claude Code plugin — layout, plugin.json, marketplace registration, versioning, README/CHANGELOG, validation gates.
---

## Layout

A plugin is a directory under plugins/ with one required manifest and
any mix of content directories:

    plugins/<name>/
      .claude-plugin/plugin.json   required manifest
      skills/<skill>/SKILL.md      knowledge loaded on contextual triggers
      agents/<agent>.md            delegated personas for the Agent tool
      commands/<command>.md        explicit user-invoked slash actions
      hooks/hooks.json             mechanical event handlers + scripts
      README.md                    optional, recommended once non-trivial

Every content directory is optional; ship only the kinds the plugin
actually needs. An empty scaffold directory is clutter, not foresight.

## plugin.json

Four core keys — name, version, description, author:

    {
      "name": "<name>",
      "version": "0.1.0",
      "description": "<one sentence: what it does and when it fires>",
      "author": { "name": "<who>", "email": "<where>" }
    }

- name must equal the directory name under plugins/ and the marketplace
  entry name — the validator cross-checks all three
  (scripts/validate.sh:15-23).
- New plugins start at 0.1.0.
- One optional key earns its place: dependencies — an array of plugin
  names (or { "name", "version" } objects) auto-installed with this
  plugin. Use it for hard couplings and meta-bundles; never to force
  optional companions on the user.
- Beyond that, add no extra keys; the manifest is a registration
  record, not a feature surface.

## Registration

Every directory under plugins/ must be listed in
.claude-plugin/marketplace.json — validators reject orphan dirs
(scripts/validate.sh:26-30). The entry shape:

    {
      "name": "<name>",
      "source": "./plugins/<name>",
      "description": "<same story the plugin.json tells>"
    }

Add the marketplace entry in the same change that creates the
directory. A plugin directory committed without its entry fails
validation immediately, and a "register it later" plan leaves the tree
broken for everyone in between. Creation and registration are one
atomic step.

## Bundle membership (the rider validation cannot catch)

A new plugin — and a new **agent** inside an existing plugin — is not done when its
files pass validation. Bundles advertise a set; adding to the set without updating
the bundle makes the bundle lie, and no gate flags it:

- **`everything`** depends on every non-suite (leaf) plugin. A new leaf plugin must
  be added to its `dependencies`, or the aggregate install silently omits it. (The
  validator's everything-count check catches a missing plugin only via the README
  count — keep both in step.)
- **`*-suite` bundles** (`quality-suite`, `frontend-suite`, `php-suite`, `db-suite`,
  `process-suite`, `taskmaster-suite`) depend on a themed subset and drive an
  uninstall prune list. A new plugin or agent in a suite's domain joins that suite's
  `dependencies` AND its prune list — a suite that claims "all worker agents" must
  actually contain them.

Do this in the same change as the addition. "Register the bundle later" is the same
broken-tree trap as skipping marketplace registration.

## Composition: pick the smallest artifact

Each artifact kind answers a different question — choose by trigger,
not by habit:

- Skills carry knowledge and judgment. They fire contextually when the
  dispatcher matches their description; the model decides relevance.
- Agents are delegated personas: a system prompt plus tool set that
  runs a whole subtask and reports back. Use when work benefits from
  isolation, not just knowledge.
- Commands are explicit user-invoked actions. Use when the user should
  deliberately start the behavior by name, never by inference.
- Hooks are mechanical guarantees bound to events. Use only when
  missing even one firing is unacceptable; they run without judgment.

Prefer the smallest artifact that does the job: a skill before an
agent, an agent before a command-plus-hook apparatus. A plugin whose
every feature is a hook is usually a skill wearing armor; a plugin
with one command and no knowledge is usually a shell alias.

## Release hygiene

- Bump the plugin's version on every content change — skills, agents,
  commands, hooks, README included. An unchanged version number on
  changed content makes installs undiagnosable.
- Write one CHANGELOG entry per marketplace release, listing every
  plugin touched in that release. The changelog is per-release, not
  per-plugin.
- Keep one README table row per plugin in the marketplace root README,
  so the catalog reads at a glance without opening directories.
- Keep plugin.json description and marketplace description telling the
  same story; drift between them confuses discovery.

## Validation gates

Run bash scripts/validate.sh before committing. It enforces, among
other rules:

- every marketplace entry resolves to a directory with a valid
  plugin.json whose name matches (scripts/validate.sh:15-23);
- every plugins/ directory is registered — no orphans
  (scripts/validate.sh:26-30);
- every SKILL.md has matching name, a description, and a 100–150 line
  body (scripts/validate.sh:34-47);
- every doc string shaped like /<plugin>:<command> names a registered
  plugin (scripts/validate.sh:65-72);
- every hooks.json parses and its scripts are executable
  (scripts/validate.sh:74-82).

Treat a red validator as a broken build, not a suggestion.

## Failure modes

- Orphan directories. A plugin dir without a marketplace entry fails
  validation and is invisible to installs — worst of both worlds.
- Name mismatches. Directory says one thing, plugin.json another,
  marketplace a third; the validator flags it, but the fix is one
  name chosen once and propagated everywhere.
- Dangling command references. Docs mentioning a
  /<plugin>:<command> for a plugin that was renamed or never
  registered fail the reference check and mislead readers.
- Versions never bumped. Ten content changes at 0.1.0 means no one —
  including you — can tell which behavior any install actually has.
- Kitchen-sink plugins. Unrelated skills bundled under one name force
  users to install everything to get anything; split by audience.
