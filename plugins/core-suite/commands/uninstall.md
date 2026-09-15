---
description: Uninstall the core-suite bundle AND its bundled dependencies, scope-aware — computes the removal set from the bundle's own manifest (works even when installs carry no auto-install markers), shows the exact list for confirmation first, and never touches plugins you exclude.
---
<!-- generated from templates/suite-uninstall.md.tmpl by scripts/generate.sh — edit the template or .chassis.json, not this file -->

Uninstall this bundle cleanly. Do NOT rely on `--prune` alone: install records
frequently carry no auto-install markers (installs made before dependency
tracking, or via the /plugin menu), and `claude plugin uninstall` defaults to
the `user` scope while bundles are commonly installed at `project` or `local`
scope — the combination silently removes nothing. Compute the removal set
yourself:

1. Locate the install. Run `claude plugin list --json` and collect every entry
   whose id starts with `core-suite@` — note each `scope` and `installPath`.
   Not installed at any scope → report that plainly and stop. Installed at
   several scopes → handle each scope in turn below.
2. Build the removal set per scope. Read the bundle's dependency list from its
   installed manifest:

   ```bash
   jq -r '.dependencies[]?' "<installPath>/.claude-plugin/plugin.json"
   ```

   A dependency is a removal candidate when it is installed at the same scope.
   KEEP a candidate — and say why — when another installed bundle at that
   scope (another `*-suite`) also lists it in ITS manifest's
   dependencies.
3. SPLIT THE CANDIDATES BY PROVENANCE, and default to keeping. Read
   `~/.claude/plugins/installed_plugins.json` and check each candidate's record
   for an `auto` marker:

   - **auto-installed** (record carries `auto`): this bundle put it there.
     Propose removing it, pre-selected.
   - **provenance unknown** (no `auto` marker): treat as HAND-INSTALLED and
     propose KEEPING it, listed separately and NOT pre-selected.

   This split is the whole point and it is not a formality: measured
   2026-09-15, the `auto` marker was present on 40 of 725 install records on
   one real machine (5.5%), and four projects with a suite installed carried
   **zero** markers across 19-32 plugins. The marker is a bare boolean with no
   parent reference, so it can tell you "something auto-installed this" and
   never "THIS bundle did". Absence of a marker is therefore not evidence of a
   hand install either — it is absence of evidence, and the safe reading of
   absent evidence is "leave it alone". Removing a plugin the user installed
   deliberately is the expensive direction; leaving one behind costs them one
   command.
4. Honesty check: run `claude plugin prune --dry-run -s <scope>`. If it says
   "nothing to prune" while candidates exist, the installs carry no
   auto-install markers — and then, by step 3, N is zero and there is no
   automatic removal set at all. Say exactly that: this bundle cannot prove it
   installed anything, so only its own manifest comes out, and the M plugins it
   lists are yours to remove by hand if you want them gone. Do NOT describe an
   "explicit removal list" as the mechanism here; step 3 has just moved every
   candidate into KEEP, so that list is empty.
5. Confirm as a selectable choice (AskUserQuestion), showing the two groups from
   step 3 separately and naming the count in each. **When N is 0 — the common
   case on a real machine — collapse to three options**, because "remove the
   bundle and its 0 auto-installed plugins" and "remove the bundle only" are the
   same action and offering both asks the user to pick between identical
   choices: "Remove the bundle only (Recommended)" / "Let me choose from the
   full list" / "Cancel". When N is 1 or more, offer four: "Remove the bundle
   and its N auto-installed plugins (Recommended)" / "Remove the bundle only" /
   "Let me choose from the full list" / "Cancel". Either way state plainly, in
   the question, that the M unknown-provenance plugins are being kept and why.
   On the choose-from-full-list option, show every candidate and take an
   explicit pick. This removes many plugins at once — never proceed without the
   explicit pick, and never pre-select a plugin whose provenance you could not
   establish.
6. On confirm, per scope: uninstall the bundle first, then each confirmed
   dependency, always passing the scope explicitly:

   ```bash
   claude plugin uninstall core-suite -s <scope> --prune -y
   claude plugin uninstall <dependency> -s <scope> -y
   ```

   (`--prune` on the bundle line is kept for installs that DO carry auto
   markers — it is a harmless no-op otherwise.)
7. Verify with `claude plugin list --json` again. Report four lists: removed,
   kept-because-another-bundle-needs-it, kept-because-provenance-unknown (say
   "you may have installed these yourself — remove any with
   `claude plugin uninstall <name> -s <scope> -y`"), and failed (with the error
   verbatim). Note that a restart or
   `/plugin` refresh may be needed before the change is fully visible in the
   session.
