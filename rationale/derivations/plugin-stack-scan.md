# stack-scan scripts: the comment text moved out of the code (2026-10-28)

The text below was moved verbatim on 2026-10-28 from the files named in the `##` headings, with only each comment's `# ` leader (and the indentation before it) removed; the lines each file kept are not repeated here. A pointer by name was left in each file's header, `# Why, limits, history: rationale/derivations/plugin-stack-scan.md § <heading>`. Standing: `recorded` — no gate reads this file, and its dates, measurements and citations are as they stood on the day it moved.

## plugins/stack-scan/scripts/licence-scan.sh

### Header

The file keeps the usage line, the MODE list, the policy resolution and the exit codes, which `--help` prints.

```text
Dependency-licence scan, lockfile-driven and distribution-mode aware.

THE THREE THINGS THIS DOES THAT READING package.json DOES NOT:

1. TRANSITIVITY. Measured on a lockfile shipped inside this very marketplace:
   scripts/__tests__/fixtures/transitive-mpl/package-lock.json (a frozen shadcn+Vite lockfile) has 170 entries, twelve of
   them MPL-2.0 (lightningcss plus its eleven platform binaries, pulled in by
   Tailwind v4), and NONE of the twelve appears in package.json. A direct-dep
   read reports "all MIT/ISC, clean". Nobody enumerates 170 lock entries by
   hand; that is the whole argument for a script.

2. THE DISTRIBUTION-MODE CONDITIONAL. The same licence is benign or hazardous
   depending on how the artifact ships, and the axes run OPPOSITE ways:
   MPL-2.0/LGPL bite a distributed binary and are routine in a SaaS backend;
   AGPL is the exact inverse, biting hardest on SaaS — where the instinct "we
   don't distribute, so copyleft doesn't apply" is precisely wrong. The mode is
   the decision, and it is not in any manifest.

3. THE lockfileVersion TRAP. npm lockfileVersion 1 carries no `license` key at
   all, so a naive scan of an older repo returns zero findings — a silent false
   PASS. That is why exit 3 exists and why "unresolvable" is reported loudly
   rather than counted as clean.
```

```text
root, else exit 3. Deliberately NOT inert-by-default: `--distribution saas`
alone is a complete, useful run with no config file to write first.
```

```text
HONEST LIMITATION, and it is a large one: this reads DECLARED metadata, never
legal truth. It also searches only three directory levels for lockfiles, so a
deeply nested monorepo package is out of scope unless scanned directly. It is blind to dual-licensed packages that declare only one side,
vendored code with no manifest entry, a LICENSE file contradicting the declared
SPDX id, and licence changes between the version you locked and the one you
read about. It answers "does anything declare a licence this distribution mode
should not ship", never "are we compliant". Nobody should present its output as
legal advice, and the report says so.
```

### The deny table

```text
Deny sets per distribution mode. Stated as a table because the asymmetry is the
point: AGPL and MPL sit on opposite sides of the saas / distributed-binary line.
```

### No readable lockfile: naming pnpm, yarn and bun

```text
Say which lockfiles this lane reads and which it does not. npm and Composer record a
`license` field per resolved package; pnpm, yarn and bun lockfiles do not, so there is
nothing to read without resolving the registry — out of scope for an offline scan.
A pnpm/yarn/bun repo used to exit 3 with a message naming only two filenames, reading
as "no dependencies here" when the truth is "this lane cannot see yours".
```

## plugins/stack-scan/scripts/pick.sh

### Header

```text
Interactive multi-select over a numbered rows file — the unbounded
alternative to AskUserQuestion's 4x4 option cap. Run BY THE USER via the
`!` prefix (needs a real TTY); the model then reads the PICKED line from
the conversation. Usage:
  ! bash <path>/pick.sh rows.txt
rows.txt: one row per line, "<number><TAB><label>".

The two branches select differently and only the numbered one parses tokens.
fzf selects rows directly — typing filters the list, so there is nothing to
parse and no `N-M` range to expand. The numbered prompt takes row numbers,
`N-M` ranges, and label NAMES; it resolves a name itself rather than
rejecting it, because rejecting one would make a `laravel` that fzf accepts
by typing depend on whether the user happens to have fzf installed. Name
matching is case-insensitive, an exact hit on the label's leading name field
wins outright, else a substring hit, and a name matching several rows is
reported and skipped rather than guessed at.

CONTRACT: every path past the three invocation errors prints exactly one
`PICKED: <numbers>` line and exits 0. An abort is an EMPTY pick, not a
failure — fzf ESC (130), fzf no-match (1) and Ctrl-D at the prompt each
print a bare `PICKED:`, because the calling skill parses that line and has
no contract for a bare non-zero exit; under `set -e` + `pipefail` all three
used to kill the script before it printed anything. A rejected token goes to
stderr and never aborts the pick. A missing or unreadable ROWS_FILE and an
unopenable TTY are real errors and still exit 1 — readability is checked here
because `-f` alone let an unreadable file reach `cut`, which failed under
`set -e` and leaked a raw `Permission denied` in place of the usage line.

PICK_TTY overrides the device the numbered prompt reads from — the seam that
lets the harness drive the parser headless. Standing: gate — this plugin's
scripts/__tests__/pick.test.sh covers it and runs on every PR. Until 2026-09-14
two plugins shipped byte-identical copies; both scouts live here now, one copy.
```

### The pasteable retry line

```text
Single-quoted: this line exists to be pasted verbatim, and an unquoted
path with a space in it pastes as two arguments.
```

### noglob

```text
Typed input is split on whitespace; noglob keeps a token like `*` a token
instead of letting it expand to whatever is in the current directory.
```

### The rows read once, and the range ceiling

```text
Read the rows ONCE: the valid-number set, and the highest row NUMBER a range
clamps to. `1-1000` against a 20-row file used to build 1000 tokens and run
1000 `cut | grep` pipelines.

The ceiling is the highest number, NOT the line count. Report numbers are
stable across a run while installed rows are filtered out of the picker
(references/picker.md), so the rows file is sparse whenever anything is
already installed — which is every run after the first. Clamping to the line
count made `1-8` over rows 1,2,5,8 pick `1 2`: rows 5 and 8 exist, were
asked for, and were dropped in silence while the diagnostics blamed rows 3
and 4, which do not exist.
```

### Leading zeros

```text
Leading zeros: `08` is a row number, not octal, and the digit-length guard
below must not read `007` as three digits. Parameter expansion rather than
`sed`, so the cost is one subshell per range operand and no extra process.
```

### match_rows

```text
Row numbers whose label matches $1. Exact-name hits suppress substring hits,
so `react` picks `react` and not also `react-native`.
```

### fzf's exit codes

```text
ESC exits 130 and no-match exits 1; `pipefail` would turn either into a
dead script, so the whole pipeline is caught and read as an empty pick.
```

### The newline after the prompt

```text
The prompt above ends without a newline. A terminal echoes the user's
ENTER and closes the line; nothing else does, and then PICKED: would be
appended to the prompt line where no `^PICKED:` parse can see it.
```

### Ten-digit operands

```text
`$(( ))` wraps mod 2^64 without a word, so a 20-digit operand came
back as a small in-range number and the clamp below never fired —
a wrong pick reported as a clean success. No row number needs ten
digits; refuse them before any arithmetic touches them.
```

### Gaps in a sparse rows file

```text
Emit only numbers the file actually carries: a gap in a sparse
rows file is a filtered-out row, not a token to complain about.
```

## plugins/stack-scan/scripts/scan.sh

### Header

```text
scan.sh — the mechanical core of stack-scan: required-vs-installed inventory
from manifests, lockfiles, runtimes, and container files, as one markdown
report on stdout. Deterministic parses only; interpretation (upgrade advice,
EOL judgment) stays with the skill that wraps this.

Usage: scan.sh [project-root]     Exit 0 always (a report, not a gate).

Residual: covers node/php/python + docker files. Go/Rust/.NET/JVM rules exist
in references/ecosystems.md as instructions, not code — a repo in those
stacks gets the "not covered by scan.sh" line, never a silent zero.
```

### The framework list

```text
Top framework floors worth pinning advice to. The list is what the report NAMES; a
package absent from it leaves no row at all, so an Astro-, Svelte- or Angular-only
repo scanned as "node + a lockfile" and nothing else (panel 2026-09-22, WEB 12). It
does NOT decide what is installed and it never will be complete: a framework missing
here is invisible, not misreported, and the honest fix is to add the name.
```

## plugins/stack-scan/scripts/sync-plan.sh

### Header

```text
sync-plan.sh — the scope arithmetic behind `/stack-scan:suggest --sync`. Given the
scout's recommended set for this project, it reads the three settings files the CLI
merges for `enabledPlugins` (user, then project, then local — later wins) and prints
one TSV row per plugin of this marketplace: what --sync should do with it, at which
scope, and the exact command that does it. Read-only: it never runs `claude`; the
skill renders the plan, asks, and runs the command column.

Why a script: the precedence is where prose went wrong. A plugin enabled at user
scope looks "installed" from every project, so the scout's picker offered nothing in
a repo that relied on user scope; a `false` in .claude/settings.local.json beats a
user-scope `true`; local scope is one checkout's path, so a linked worktree starts
bare. Each of those is a row class below with a harness case behind it.

Usage: sync-plan.sh [--persist] [--root DIR] [--catalog FILE] [--] NAME...
  NAME       the scout's recommended set (tier 1 fired + tier 2 core). stack-scan is
             always added: a project moved off user scope must keep the tool that
             manages it.
  --persist  target scope project (.claude/settings.json) instead of local.
  --root     the project root (default: .).
  --catalog  the marketplace's plugin list (default: this plugin's generated
             skills/plugin-scout/references/catalog.md).

Output: class<TAB>name<TAB>scope<TAB>command, `-` for no command, sorted by class:
  add          recommended, enabled nowhere            → install at the target scope
  move         recommended, enabled only at user scope → install at the target scope
  held         recommended, but a settings file says false → never re-enabled
  extra        enabled at local/project, not recommended → uninstall at that scope;
               a project-scope extra gets a command only under --persist (that file is
               the team's)
  duplicate    a local copy of a project-scope entry, recommended or not → uninstall
               the local copy (the project entry still enables it, so removing the
               copy changes nothing but the record)
  ok           recommended and enabled at local or project — nothing to do
  machine-wide not recommended, enabled only at user scope — left alone (other
               projects may rely on it)
  unknown      enabled, but not in the catalog: removed from the marketplace, or newer
               than this stack-scan
  note         worktree: a linked git worktree under a local target (local scope is
               this path only; --persist writes the file every worktree checks out)
  offramp      user scope still enables this marketplace's plugins; name = how many,
               command = the one-shot user-scope removal, printed, never run here

Exit: 0 plan printed (possibly empty); 2 bad argument, no jq, a NAME the catalog does
not list, or a settings file that exists and is not a JSON object — a plan built on a
misread file would install or remove the wrong set.

Residual: reads neither managed policy settings, a --settings file nor a --plugin-dir
load (the same three all-plugins' hint.sh skips), and not the install records — a
project-scope `true` for a plugin this machine never installed classes as enabled.
```

