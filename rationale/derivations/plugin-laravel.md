# laravel: derivations (2026-11-08)

Comment text moved out of the laravel plugin's scripts, per the header rule in `CLAUDE.md`. Standing: `recorded` —
no gate reads this file.

## plugins/laravel/scripts/i18n_parity.py

A copy ships as `plugins/web-dev/scripts/i18n_parity.py`, whose header points here too: a laravel-only install
needs it for `lang/`, a web-dev-only install for i18next and vue-i18n, and no plugin may depend on another. Each
copy carries a `# TWIN:` line naming the other, and `validate.sh` fails the build when they differ on any other
line (`pc_twin_files`, **gate**, the mechanism the preview-guard and `contrast.mjs` twins already use;
`rationale/derivations/scripts-lib.md` § pc_twin_files). It proves the copies match, not that either is right.

### Why it exists

Roadmap row CT3 (2026-11-07 integration roadmap, Track 4): missing keys and placeholder mismatches across Laravel
`lang/` and i18next or vue-i18n JSON. Neither plugin had any i18n content. The row cites the alirezarezvani
`i18n-localization` skill as the idea; no code or text was taken from it. It is a set comparison across every
locale file at once, which a reader working one file at a time has no way to perform. Nothing here is measured
against a control arm.

### Design

- **PHP is parsed, never executed.** `php -r 'echo json_encode(require $argv[1]);'` would be exact, but `require`
  runs the file. The files are the user's own code, yet the checker also runs while reviewing someone else's
  branch, and a lang file is PHP that can do anything. A static read gives the same answer for the literal
  `return [...]` shape and the same result with or without `php` on PATH. Anything else (a call, a constant, a
  variable, heredoc, interpolation, `array_merge`) is reported `unparsed` with file and line. The keys of an
  unparsed file are never reported missing: that would be a guess.
- Cross-checked once on 2026-11-08 against PHP 8.5.12, flattening `json_encode(require …)` for three fixture files:
  escapes (`\x41`, `\101`, `\u{…}`, `\$`, `'it\'s'`), auto-index after an explicit int key, `array()` and `[]`,
  literal concatenation, all three comment forms, `declare`, and a closing `?>`. All three agreed. The harness
  does not run PHP. The local `php` is a lerd container shim that cannot read `/tmp`, where the harness builds its
  fixtures, so the harness's literal expectations carry that check from here on. Each escape has a key that only
  the translation holds, so a wrong decode renames the `extra` finding. The auto-index list is one item shorter in
  the translation, so a wrong index names another missing key. `//` and `#` comments, `declare`, `?>` and
  concatenation sit in silent fixtures that turn unparsed or lose a placeholder when misread. No fixture holds a
  `/* */` comment.
- **Laravel placeholders fold case.** Laravel fills `:name`, `:Name` and `:NAME` from one replacement, so a German
  `:Name` against an English `:name` is not a mismatch.
- **Plurals compare the union of placeholders across segments.** The `|` segment count and the `{0}` / `[1,*]`
  intervals are not compared. How many plural forms there are is a property of the language (Russian three,
  Japanese one), and translators restructure intervals with it. A placeholder dropped from every segment is
  still caught.
- **A Laravel JSON key is its own base-language string.** An app need keep no `lang/en.json` at all, so the
  reference set is every locale's JSON keys. The reference string is the base file's value when it has the key, else the key. A
  translation key absent from the base file is not extra: `__('Some text')` falls back to the key itself.
  That waiver of a base locale holds only while no locale has a PHP file; with PHP present and no base, the
  layout is `base-missing` (exit 2). A base with JSON and no PHP file (Laravel 11+ keeps `en` inside the
  framework) skips the per-file PHP comparison rather than calling every translation file extra.
- **i18next plural families.** A `<k>_other` key makes its `<k>_zero` … `<k>_many` siblings (and the `_ordinal_`
  set) one family, compared as one key with the union of its members' placeholders. Which forms a language needs
  is CLDR data the script does not bundle, so a German file with only `_other` passes. A `_one` with no `_other`
  stays a plain key. `{{- var, format}}` reads as `{{var}}`; `$t(key)` nesting is compared as a token.
- **vue-i18n.** `{name}` and `{0}` interpolation and `@:key` links compare as sets. A link modifier (`@.upper:`) and
  argument order are ignored, and `{'literal'}` is not a placeholder.
- **Format follows the path, then `package.json`.** `locales/` and `public/locales/` read as i18next;
  `src/locales/`, `src/i18n/` and `src/i18n/locales/` read as vue-i18n. A `package.json` naming exactly one of the
  two families (`*i18next*`; `vue-i18n`, `petite-vue-i18n`, `@intlify/*`, `@nuxtjs/i18n`) overrides that for the
  JSON dirs. Without the override, a react-i18next app's `src/locales/ru/translation.json` reports `_few` and
  `_many` as extra keys. The harness pins both arms.
- **Locale names** match `^[a-z]{2,3}([_-][A-Za-z0-9]{2,8})*$`. That drops `lang/vendor/` (package overrides,
  partial by design) and files such as `index.json`. In a Laravel dir, `php_<locale>.json` is skipped too:
  laravel-vue-i18n's Vite plugin generates it from the PHP files. A two- or three-letter non-locale name
  (`app.json`) is still read as a locale.
- **Exits.** 0 parity; 1 any finding, an unparsed file included, since parity is then unproven; 2 a usage error or
  no base locale in any layout (one layout lacking it while another has it is a `base-missing` finding, exit 1);
  3 no locale files in the seven probed dirs.

### Standing

**Gate where run**: exit 1 is a failing verdict for whoever runs it. Whether it runs is **recorded**: the
`laravel-best-practices` and `vite-best-practices` bodies say to run it, and nothing checks that a review did.

### What it does not catch

Untranslated (copied base) or empty values; the plural forms a language needs; a placeholder repeated a different
number of times; YAML, `.ts` and `.js` locale files; keys built at runtime, and whether a key is used at all;
i18next v3 `_plural` / `_0` suffixes; `lang/vendor/` overrides; locale dirs outside the seven probed paths (a
monorepo app needs its own root passed); ICU MessageFormat and next-intl `messages/`. Translation PHP files when
the base locale has none under `lang/`: they are compared against nothing, and the run can still say parity.

## plugins/laravel/scripts/__tests__/i18n-parity.test.sh

The same bytes ship as `plugins/web-dev/scripts/__tests__/i18n-parity.test.sh`, each copy testing its own plugin's
script. The harness copies carry no `# TWIN:` line, so they are identical by convention only. While the scripts
match, CI runs both copies, so harness drift loses nothing.

59 asserts on fixtures built under `mktemp`. For each format: a missing key, an extra key and a placeholder
mismatch. Also plural families (i18next `_one/_few/_many/_other`, Laravel and vue `|` segments), nested PHP arrays,
PHP escapes and auto-index, six refused PHP shapes reported and not guessed, the `package.json` format override,
laravel-vue-i18n's `php_*.json`, a Laravel 11+ base with no PHP file, and exits 0, 1, 2 and 3. The silent arms are
the nearest inputs: `:Name` against `:name`, fewer plural segments, a link modifier, reordered list arguments,
`{'@'}` against `{'#'}`.

Five mutants of the script were run against it on 2026-11-08. They dropped the case fold, the plural families,
the unparsed report (read as empty) and the Laravel JSON key-as-source rule, and stopped reading vue links. Each
drew between 1 and 13 FAIL lines. A review the same day found asserts that could not fail, so eight more mutants
followed: auto-index ignoring an explicit key, an `_one` family without `_other`, `{'literal'}` read as a
placeholder, and one per PHP escape (`\x`, octal, `\u{}`, `\$`, `\'`). The pre-review harness passed seven of them
with no FAIL line; the current one fails each, with 1 to 5 FAIL lines.
