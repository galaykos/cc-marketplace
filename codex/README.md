# Install in Codex

This is a separate Codex distribution of the Claude Code marketplace. Claude
packages remain in `../plugins/`; Codex installs the generated packages in
`codex/plugins/` through the root `.agents/plugins/marketplace.json` catalog.

## Install

From a checkout containing the Codex catalog:

```bash
codex plugin marketplace add /absolute/path/to/cc-marketplace
python3 codex/install.py install quality-suite
python3 codex/install.py install quality-suite --apply
```

The installer previews changes unless `--apply` is supplied. Replace
`quality-suite` with any plugin or suite in [the catalog](catalog.json).
Registering the marketplace makes packages available; it does not install them.
After installation, start a new Codex session. Review and trust plugin hooks in
Codex before relying on them. Python 3, bash, and jq are required for the adapters;
The suite installer and shell adapters target macOS/Linux.
`design-lab` also needs Node.js. Its remote ReUI MCP server requires separate
user authentication; the local registry server works independently.

You can install a **leaf plugin** directly with
`codex plugin add database@cc-plugins-codex`, or through the plugin browser.
For **suites**, use the installer: Codex does not expand this marketplace's suite
membership automatically. The suite package also contains a `manage-suite` skill
and a self-contained copy of the installer. Use the helper for explicit leaf
installs too if you want its ownership tracking to protect them later.

Commands become skills named `command-<name>` within the owning plugin; for
example database's former review command is its `command-review` skill. Select
it from the available skills or ask Codex to use it. Existing domain skills retain
their names. Agent rubrics are bundled resources; native delegation is used when
available and permitted, with inline execution otherwise.

## Remove or update

```bash
python3 codex/install.py uninstall quality-suite
python3 codex/install.py uninstall quality-suite --apply
```

The journal at `~/.codex/cc-marketplace/install-state.json` records suite roots and
plugins added by this installer. Removing a suite preserves preexisting installs,
explicit leaf roots, and dependencies needed by another recorded suite. A failed
operation records progress; repeat it to reconcile and resume. Preview can read an
existing journal but never writes one. `--state` selects a different journal.
Keep the same journal across installs and removals. It cannot detect a later
direct CLI install as renewed ownership of an already-owned dependency.

After pulling source changes, run `python3 scripts/build_codex.py --check`.
Local checkouts are read directly; for a Git-registered marketplace, first run
`codex plugin marketplace upgrade cc-plugins-codex`. Then reinstall each affected
package with `codex plugin add <name>@cc-plugins-codex` and start a new session.
The generator appends a deterministic content hash to each native version, so
adapter changes invalidate the package cache without changing Claude versions.
The suite helper skips installed packages; use the direct add command for updates.
Merely editing generated files does not refresh the installed cache. This repository does not modify your Codex configuration during
builds or tests.

## Compatibility and limitations

[Every plugin's disposition](COMPATIBILITY.md) is generated alongside the catalog.
Native overrides replace installation discovery, task orchestration, model-tier
selection, and history workflows. Hooks adapt shell and multi-file patch payloads
and retain the original guard decisions. Project state is isolated under
`.codex/cc-marketplace/`; add that working-state directory to your project's
ignore rules if you use stateful workflows.

Some source behavior has no reliable matching host contract:

- Candor/architecture transcript gates and verbosity measurement become explicit
  evidence checks, not automatic enforcement.
- Hindsight uses accessible history and explicit reflection; it does not parse a
  guessed Codex transcript format or claim passive skill-use collection.
- Skill routing consults Codex's available skill catalog; it does not infer enabled
  plugins by scanning cached siblings.
- Artifact-event guards become explicit rendered-preview steps.
- Reviewer observation and transcript reduction checks are manual; task-runner's
  registered-run filesystem/HEAD checks remain available.

Hook tests exercise the adapter processes and real source helpers, including
negative controls. They do not prove that a particular Codex host has enabled and
trusted hooks. Guards retain their original fail-open dependencies and heuristic
coverage; shell-driven file edits and later terminal input are not fully covered.

## Maintain

Edit shared sources in `plugins/` or native replacements in `codex/adapters/`.
Generated files in `codex/plugins/`, `codex/catalog.json`, `codex/COMPATIBILITY.md`
and `.agents/plugins/marketplace.json` must not be hand-edited.

After changing a Claude Code plugin, run the commands below and commit the
regenerated files together with the source changes. Content normally carries
through automatically, but new host-specific behavior needs an adapter review.
Overrides in `codex/adapters/overrides/` replace their corresponding source files;
review them when those source workflows change so improvements are not masked.

```bash
python3 scripts/build_codex.py --write
python3 scripts/build_codex.py --check
python3 -m unittest discover -s scripts/codex_tests -v
python3 scripts/codex_host_check.py  # optional: installed Codex CLI required
```

The generator has no third-party dependencies. CI rebuilds into a temporary
folder and compares bytes and executable modes, and runs the adapter/installer
behavioral tests. Original Claude validation remains separate.

This updates the repository distribution only. Users still need to
[refresh their installed packages](#remove-or-update) and start a new session.

Packaging follows [OpenAI's plugin format](https://developers.openai.com/plugins/build/plugins)
and [Codex hook contracts](https://learn.chatgpt.com/docs/hooks). Support for native
hooks depends on the host version; check your installed Codex's current help and
hook settings if hooks are unavailable.
