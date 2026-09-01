---
description: Uninstall the quality-principles-suite bundle AND its bundled dependencies, scope-aware — computes the removal set from the bundle's own manifest (works even when installs carry no auto-install markers), shows the exact list for confirmation first, and never touches plugins you exclude.
---
<!-- generated from templates/suite-uninstall.md.tmpl by scripts/generate.sh — edit the template or .chassis.json, not this file -->

Uninstall this bundle cleanly. Do NOT rely on `--prune` alone: install records
frequently carry no auto-install markers (installs made before dependency
tracking, or via the /plugin menu), and `claude plugin uninstall` defaults to
the `user` scope while bundles are commonly installed at `project` or `local`
scope — the combination silently removes nothing. Compute the removal set
yourself:

1. Locate the install. Run `claude plugin list --json` and collect every entry
   whose id starts with `quality-principles-suite@` — note each `scope` and `installPath`.
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
3. Honesty check: run `claude plugin prune --dry-run -s <scope>`. If it says
   "nothing to prune" while candidates exist, the installs carry no
   auto-install markers and `--prune` would remove nothing — the explicit list
   from step 2 is the real mechanism; say so in the summary.
4. Confirm as a selectable choice (AskUserQuestion) showing the exact removal
   list (the bundle plus every candidate, per scope): "Uninstall the listed
   plugins now (Recommended)" / "Let me exclude some first" / "Cancel". On
   exclude, ask which to keep, then re-confirm the reduced list. This removes
   many plugins at once — never proceed without the explicit pick.
5. On confirm, per scope: uninstall the bundle first, then each confirmed
   dependency, always passing the scope explicitly:

   ```bash
   claude plugin uninstall quality-principles-suite -s <scope> --prune -y
   claude plugin uninstall <dependency> -s <scope> -y
   ```

   (`--prune` on the bundle line is kept for installs that DO carry auto
   markers — it is a harmless no-op otherwise.)
6. Verify with `claude plugin list --json` again. Report three lists: removed,
   kept (with the reason — excluded by you, or required by another installed
   bundle), and failed (with the error verbatim). Note that a restart or
   `/plugin` refresh may be needed before the change is fully visible in the
   session.
