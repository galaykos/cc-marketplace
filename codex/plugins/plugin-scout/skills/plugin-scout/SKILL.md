---
name: plugin-scout
description: "Use when selecting or installing Codex marketplace plugins for a repository; scan stack evidence, compare the complete leaf catalog, and install the selected compatible packages."
---

Read [the Codex execution contract](../../references/codex.md) before using helpers or delegating.

# Scout a project

Read the target project's manifests without running package managers. Include declared workspace member manifests. Match exact dependency keys, configuration filenames, and public example configuration; do not print secret values. Use `references/signals.md` for signal definitions and `references/catalog.md` for the marketplace inventory. These references describe plugin capabilities, not the Codex installation protocol.

Build three groups, with every leaf appearing once: signal-backed plugins with file/key evidence; the core from `references/any-core.md`; then the remaining leaves, including candidates whose signals did not fire. Exclude suites and plugin-scout from the leaf count. Identify up to five remainder entries worth considering with a project-specific reason; do not treat those reasons as detected evidence. An absent stack signal is a valid result.

Use the current session's available skill/plugin catalog to mark capabilities available here. Absence from that catalog is not proof that a plugin is absent from disk: mark uncertain installation state honestly. Show names, purposes, stack evidence, and the totals, with no omitted leaves. Offer suites separately when they cover several picks. Consult the generated Codex catalog and compatibility report before offering an installation; disclose workflow fallbacks or unavailable enforcement for the selected package.

## Install the selection

Resolve the plugin root as two directories above this skill's directory (the parent of `skills/`). The bundled `scripts/install.py` and sibling `scripts/catalog.json` implement the native installation workflow. Run `python3 <resolved-plugin-root>/scripts/install.py install <name>` to preview a selection and add `--apply` to execute authorized picks. Read its `--help` for supported scope/options. The native protocol is `codex plugin list --json`, `codex plugin marketplace add <repo-path>`, and `codex plugin add <name>@cc-plugins-codex`; prefer the helper so catalog names and bundle expansion are validated. Codex packages live under `codex/plugins/`; never run the source marketplace's host-specific install commands or edit another host's settings.

A request to suggest plugins authorizes scanning and recommendations. A request to install named picks authorizes those installations. `--yes` selects signal-backed and core leaves; `--full` selects all stack-relevant leaves after displaying exclusions and the concrete install list, with `--full --yes` authorizing that list. `--all` shows every eligible choice. Parse `--stack` against `references/stack-relevance.md`; reject empty or unknown tokens. `--persist` and `--global` are mutually exclusive scope requests, not portable CLI flags: map only to scope options the real installer supports. If a requested scope is unavailable, report that constraint before any install.

Execute only the authorized selection, check each exit status and resulting package/registration state, and report successes and failures individually. If installation is unavailable in this environment, provide the exact documented steps and identify that no installation occurred. Do not guess a Codex CLI command or claim newly installed skills are loaded into the current session.
