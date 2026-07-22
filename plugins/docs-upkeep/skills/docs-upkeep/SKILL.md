---
name: docs-upkeep
description: "Use when a change alters behavior, interfaces, setup steps, or commands — to update the documentation that just became a lie, in the same change, before it merges."
---

# Documentation Upkeep

## Core rule

A doc contradicted by the code is worse than no doc. Readers trust
documentation precisely because it is written down — they follow the stale
setup steps, call the renamed flag, copy the example that no longer runs,
and act on fiction with full confidence. Missing docs make people ask;
wrong docs make people fail silently.

The cheapest moment to sync a doc is the change that broke it. Right now
you know exactly what changed, why, and which claims it invalidates. A
week later that knowledge is gone and the sync costs an archaeology dig.

## The drift catalog — what to check after a change

Walk this list against the diff. Each item is a documentation surface that
a code change can silently invalidate:

- **README** — setup steps (install commands, prerequisites, versions),
  feature claims ("supports X" that was just removed or added), command
  examples (flags, arguments, output shapes shown in usage blocks), and
  badges/version strings baked into the prose.
- **CHANGELOG** — one entry per user-visible change, written in the
  project's existing format (Keep a Changelog, conventional sections,
  whatever is already there). If the change is user-visible and the
  changelog has no new line, that is drift.
- **API docs and docstrings** — signatures, parameter names and types,
  return shapes, raised errors, and embedded examples that must still run
  as written. A docstring showing the old parameter order is a live bug.
- **Configuration docs** — new or removed env vars, changed defaults,
  renamed config keys, and the sample config files that mirror them.
- **Architecture docs and decision records** — does the change contradict a
  standing decision doc the project already keeps? Report it as drift naming
  both the doc and the contradicting change, rather than leaving both
  claiming to be current. Never create a decision doc a project does not use.
- **Inline examples and snippets** — code blocks in any doc that claim to
  be runnable. If you cannot paste them into a shell or REPL and have
  them work, they have drifted.

## Same-change rule

Doc updates ride in the diff that caused them. The commit or PR that
renames the flag, changes the default, or removes the endpoint also
contains the README edit, the CHANGELOG line, and the docstring fix.

A follow-up ticket is where doc updates go to die: it loses the context,
it loses the urgency, and it merges a window of time during which the
docs are confidently wrong. If the doc change is too big to ride along,
that is a signal the code change itself is too big — not a reason to
defer the docs.

## What NOT to document

Upkeep discipline cuts both ways — do not create docs that will only
generate future drift:

- **Implementation details that change weekly.** Internal helper names,
  private module layouts, transient class diagrams. They churn faster
  than anyone reads them.
- **Generated content.** Anything derivable from the code by a tool
  (API references from docstrings, CLI help from the parser) should be
  generated, never hand-maintained in parallel.
- **Line-by-line restatement of the code.** A comment or doc that says
  what the next line already says is pure drift liability.

Docs earn upkeep only when someone acts on them. If no reader would
change their behavior based on a doc, delete it instead of syncing it.

## Doc placement ladder

Each fact lives in exactly ONE place; every other mention links to it.
Duplicated facts drift independently — two copies of a default value are
a guarantee that one will eventually be wrong.

- **Docstring** — the contract of one unit: what this function/class
  takes, returns, raises, and guarantees.
- **README** — how to use and run the project: install, quickstart,
  common commands.
- **docs/** — architecture, design rationale, decision records: things
  that span units and outlive individual functions.
- **CHANGELOG** — what changed, when, and for whom.

When a fact seems to belong in two rungs, pick the lowest rung where a
reader would look first, and link from the others.

## Freshness signals to scan for

Cheap textual tells that a doc has quietly rotted:

- Versions and dates written into prose ("requires Node 16", "as of
  March") — check them against reality.
- Hedge words: "currently", "for now", "soon", "temporary" — these were
  promises with expiry dates.
- TODO markers older than the surrounding code — the surrounding code
  moved on; the TODO is fossilized.
- Links, especially relative paths, pointing at files that moved or were
  renamed.
- Documented commands referencing flags that no longer exist — grep the
  docs for every flag the change removed.

## Worked micro-example

A change renames the CLI flag `--out` to `--output`. The same diff must
also touch:

    README.md      — the usage block showing `mytool build --out dist/`
    CHANGELOG.md   — "Renamed --out to --output (breaking)"
    src/cli.py     — the one docstring whose example still shows `--out`

The check is mechanical: grep for the old flag name across all docs and
docstrings; zero hits means the rename is complete.

    grep -rn -- '--out\b' README.md CHANGELOG.md docs/ src/

## Boundaries

Writing NEW documentation from scratch is authoring, not upkeep — it is
a deliberate task with its own scope, not something to smuggle into an
unrelated diff. This skill keeps existing docs true; it does not decide
what deserves to be documented in the first place.

When the same kind of drift keeps recurring (every release the changelog
is reconstructed, every rename misses the README), that is a process
finding — name the missing gate so the workflow gets fixed, not just the
instance.

## Anti-patterns

- **"Docs pass later."** Later never has the context; the pass never
  happens, or happens wrong.
- **Changelog written from `git log` at release panic.** Commit messages
  are for maintainers; a changelog reverse-engineered from them misses
  what users actually experienced.
- **Examples never executed.** An example that has never been pasted
  into a shell is fiction with syntax highlighting.
- **Duplicating a fact into three files.** Three copies, three
  independent drift clocks, at most one of them right.
- **Doc-only PRs to fix what the feature PR broke.** The existence of
  such a PR is the failure — the feature PR shipped a lie.
