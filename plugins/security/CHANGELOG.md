# Changelog — security

Consumer-facing changes only. Newest first. Started at 0.12.6; earlier versions have no entries rather than invented ones.

## 0.12.8 — 2026-10-31

- **The write scan no longer warns on prose.** The five rows with no file-type gate (`mass-assignment-open`, `blade-unescaped`, `client-bundle-secret`, `raw-sql-interpolation`, `raw-html-sink`) skipped no doc file, so a Markdown report quoting `{!! $x !!}` drew `blade-unescaped`. Every row now skips `.md`, `.mdx`, `.txt` and `.rst`, and every row but `client-bundle-secret` also skips `.json`, `.yaml`, `.yml` and `.lock`: a CI workflow, a compose file or `eas.json` sets build env there, so a public-prefixed secret in one still warns. Residual: that row still warns on a JSON or YAML file that only names such a variable. `write-scan.test.sh` pins each row silent in a `.md` and warning in its code file; six of those cases fail against 0.12.7.

## 0.12.7 — 2026-10-28

- **Comments cut to what a reader needs; behaviour unchanged.** `hooks/write-scan.sh` (shared-block comments): each keeps a header saying what it does and misses, and one line per trap the code cannot show; the history moved to the marketplace repository's rationale/derivations/, which an install does not contain.

## 0.12.6 — 2026-10-28

- **Hook comments cut to what a reader needs; behaviour unchanged.** `hooks/write-scan.sh`: each keeps a header saying what it catches and misses, and one line per trap the code cannot show; the history moved to the marketplace repository's rationale/derivations/plugin-security.md, which an install does not contain. Every hook parses to the same code as before (comments ignored).
