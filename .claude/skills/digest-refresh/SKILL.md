---
name: digest-refresh
description: Use when asked to check, refresh, re-verify or update the marketplace's vendored doc digests and version claims — "is X stale", "what changed upstream", "refresh the references", "are we missing features", a `Last verified` stamp older than you like, or a `⚠ drift` line from check-doc-staleness.sh — one sweep from inventory to re-stamped files with every claim re-read from the live source.
---

# Digest refresh (cc-marketplace)

Every `references/*.md` and version-leveraging `SKILL.md` carries a stamp in
its first six lines:

    > Last verified: YYYY-MM-DD — <root doc URL>[ — npm:<pkg>@<major>[.<minor>]]

`scripts/check-doc-staleness.sh` reads the date and, with `--live`, the npm
tail and the URL. It cannot read the prose. The case that proves the gap: the
Astryx digest was 49 days old and inside every threshold on 2026-09-09, and
wrong on the package layout, the theme API and a category name, because a 0.x
package had gone 0.3 → 0.5. This skill is the half no script can do — the
re-read — and it ends by moving the stamp so the script's next run is honest.

## 1. Inventory, never from memory

```bash
bash scripts/check-doc-staleness.sh --live --inventory              # plugins/
bash scripts/check-doc-staleness.sh --live --inventory --path .claude/skills
```

One row per stamp: age, date, stamped npm, live npm, URL status, file, URL.
Order the sweep by risk, not by age:

1. `⚠ major drift` / `⚠ minor drift` rows — the package moved; the digest
   is presumed wrong until re-read.
2. `⚠ url` rows — the source moved; find the new page before anything else.
3. Rows whose `stamped_npm` is `-` — invisible to `--live`. The most common
   shape in this repo, so treat them as the second queue, not as fine.
4. Anything else over the age you were asked about.

Scope: the rows the user named, or the ones that warn. Refreshing every row
because you are there is a sweep nobody asked for; say which rows you left.

## 2. Re-read one digest against its source

For each row in scope, with the digest open beside the live page:

- Fetch the stamped URL AND the pages the digest's claims actually rest on —
  getting-started, changelog/releases, the CLI or API page. A landing page
  answers marketing; the changelog answers "what changed since the stamp".
- `npm view <pkg> version time --json | tail` for the release cadence; a
  canary/nightly dist-tag publishing daily means the digest needs a version
  pinned in its prose, not just the stamp.
- Diff CLAIM BY CLAIM: package names, install commands, peer ranges, import
  shape, theme/config API, category or command names, counts, URLs. Write
  the deltas down before editing — the list is the changelog entry.
- Check the SKILL body that reads the digest: its rules restate structure
  (imports, theming, anti-patterns). A digest refreshed under a stale SKILL
  is the drift this repo already shipped once.
- Check the neighbours that name the library: `lane.tsv`, the router's
  `rules.tsv`, `component-libraries/references/library-map.md`, commands
  that detect the stack, the plugin-scout skill's `signals.md` (in stack-scan). `grep -rn <pkg>` is
  the list; each hit is a claim too.

## 3. Rewrite, then stamp

- Rewrite structure-stable facts only. Props, options and signatures stay
  "read from the tool/docs for the installed version" — a digest that copies
  a props table is stale on the next patch.
- Add or correct the npm tail. A 0.x package is stamped `@<major>.<minor>`;
  a stable one `@<major>`. A digest with no package (a spec, a vendor doc)
  keeps the URL only, and that is the honest form, not an omission.
- Move the date to today ONLY for files you actually re-read end to end. A
  neighbouring file you only grepped keeps its old date.
- Bump the plugin (`plugin.json`) and write the CHANGELOG entry from the delta
  list — what changed upstream, then what changed here. A refresh with an
  empty delta is a date move and says so in one line.

## 4. Prove it

```bash
bash scripts/check-doc-staleness.sh --live --inventory | grep <file>   # stamp parses, no ⚠
bash scripts/validate.sh && bash scripts/check-version-bumps.sh master
bash scripts/context-budget.sh && bash scripts/generate.sh --check
```

Report per file: stamped-before → stamped-after, the delta count, and what
you did NOT re-read. Zero deltas is a real result; report it as one.

## What this cannot do (recorded, not enforced)

No script reads the prose, so a source that still answers 200 with rewritten
content passes `--live`. The trigger for this skill is a human asking or a
date someone noticed — there is no cron, and adding one would move the date
without the re-read, which is the failure the stamp exists to expose.
