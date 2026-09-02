# Changelog

## 0.2.2

### Changed
- README only: the exclusion notes name code-review's comment-discipline lane where they
  named the comment-discipline plugin (merged into code-review, 2026-09-02). Membership <!-- removed-ok -->
  and cost unchanged.

## 0.2.1

### Changed
- Regenerated `/always-on-suite:uninstall` from the shared template: it no longer
  names the `everything` meta-bundle as a scope that might also list a member, <!-- removed-ok -->
  because that bundle was removed from the marketplace. Membership and behaviour
  are unchanged.

## 0.2.0

### Removed
- **command-guard is no longer a member.** Not a quality judgement on the plugin —
  it is still shipped and still recommended, and this bundle's README now points
  at it under "Pairs well with". The reason is a new membership rule (rule 3, "adds
  no interruption you did not ask for") that command-guard's **ask** tier fails by
  construction, as its own README states: where the host classifies commands with a
  classifier of its own, a `PreToolUse` `ask` *overrides* that classifier, so the
  tier does not add a check — it replaces a silent judgement with a human click.
  Free once; paid on every prompt in every repo when the install is permanent and
  global, which is the only shape this bundle has.

  The deny tier does not have that problem and was never the objection. Install
  command-guard directly with `CLAUDE_DESTRUCTIVE_GUARD=deny-only` to keep the hard
  stops (`migrate:fresh`, `DROP DATABASE`, `rm -rf /`, `terraform destroy`) with the
  prompts silenced. That configuration is a genuine baseline; the default is not.

### Added
- **terse.** The 0.1.x README excluded it as "a per-user style choice that stays
  inert until you set a level". Inert-until-opted-in is what makes it *safe* here,
  and the pairing was the missed half: lean already prices what gets written to
  disk, and terse is the same discipline one surface over — what gets said in chat.
  Its own description puts code and files out of scope, so the two do not overlap.

### Changed
- README gains a **"What this costs, honestly"** section, because both members
  above are the bundle's two largest lines and the marketplace bundle table
  overstates one of them for this bundle's actual install shape:
  - terse is **848** always-on tokens with no level set and **1,891** with one.
    The `SessionStart` hook injects nothing until a level exists, so the off state
    is descriptions and nothing else. Net effect on the bundle, re-baselined:
    always-on 943 → **1,641**, activated 975 → **2,715**, dynamic unchanged at
    2,386 (command-guard's `PreToolUse` never ran in that channel anyway — the
    probe does not execute Bash-matched hooks, so its 0 there was never a
    measurement of silence).
  - skill-router reads ~2.3k per work-shaped prompt in that table, but the figure
    is built from **sibling** plugins' command frontmatter and the table is
    measured in the marketplace repo with all 52 leaves present. Re-measured
    against this bundle's eight members: **~602 tokens** (2,410 bytes).
- README records a limitation nothing else stated: **none of skill-router's 126
  routing rows names a plugin in this bundle**, so on a bare always-on install its
  `PostToolUse` router has nothing to route to. It is a forward-looking member —
  `/plugin-scout:suggest` brings the project tier, and skill-router is what makes
  those skills fire on edit.
- **brain** is now named in "Deliberately not included" with its reason, rather than
  being unmentioned. It fails rule 2 twice: it scaffolds a committed `brain/`
  directory, and until `/brain index` runs its `SessionStart` hook greets you in
  every un-indexed repo.
- Member count is unchanged at 8.

## 0.1.1

Baseline release. No changelog was kept before 0.2.0; this file starts here rather
than inventing entries for releases nobody recorded.
