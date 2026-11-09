#!/usr/bin/env bash
# i18n-parity.test.sh — i18n_parity.py on fixtures built here: missing, extra and placeholder findings per format, plural families, nested PHP, unparsed PHP, exits 0/1/2/3.
# Misses real-world trees, and php: no case runs PHP, so a parser read that differs from PHP's own is caught only by the fixtures' literal expectations.
# Why, limits, history: rationale/derivations/plugin-laravel.md § plugins/laravel/scripts/__tests__/i18n-parity.test.sh
set -u
IP="$(cd "$(dirname "$0")/.." && pwd)/i18n_parity.py"
command -v python3 >/dev/null 2>&1 || { echo 'SKIP: python3 not installed'; exit 0; }
[ -f "$IP" ] || { echo "FAIL: $IP not found"; exit 1; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
pass=0; fail=0

check() { # check <name> <root> <exit> [exact line fragment...] — extra args before -- go to the script
  local name="$1" root="$2" want="$3" out rc g; shift 3
  local args=()
  while [ $# -gt 0 ] && [ "$1" != -- ]; do args+=("$1"); shift; done
  [ "${1:-}" = -- ] && shift
  out=$(python3 -B "$IP" "$root" ${args[@]+"${args[@]}"} 2>&1); rc=$?
  if [ "$rc" -ne "$want" ]; then
    printf 'FAIL  %s: exit %s, wanted %s\n' "$name" "$rc" "$want"; printf '%s\n' "$out" | sed 's/^/      /'; fail=$((fail + 1)); return
  fi
  for g in "$@"; do
    if ! grep -qF -- "$g" <<<"$out"; then
      printf "FAIL  %s: no '%s' in\n" "$name" "$g"; printf '%s\n' "$out" | sed 's/^/      /'; fail=$((fail + 1)); return
    fi
  done
  pass=$((pass + 1))
}

refute() { # refute <name> <root> <fragment no output line may contain>
  local out
  out=$(python3 -B "$IP" "$2" 2>&1)
  if grep -qF -- "$3" <<<"$out"; then
    printf "FAIL  %s: '%s' should not appear\n" "$1" "$3"; printf '%s\n' "$out" | sed 's/^/      /'; fail=$((fail + 1))
  else
    pass=$((pass + 1))
  fi
}

# --- Laravel: nested PHP arrays, :name casing, plural segments, an unparsed file, JSON keys as their own source ---
L="$T/laravel"; mkdir -p "$L/lang/en" "$L/lang/de" "$L/lang/fr" "$L/lang/vendor/pkg/en"
cat > "$L/lang/en/auth.php" <<'PHP'
<?php

declare(strict_types=1);

// a line comment
return [
    'failed' => 'These credentials do not match our records.',
    'throttle' => 'Too many login attempts. Please try again in :seconds seconds.',
    "greeting" => "Hello, :name!\n",  # a hash comment
    'long' => 'part one ' . 'part two :count',
    'apples' => '{0} No apples|{1} One apple|[2,*] :count apples',
    'pears' => ':count pear|:count pears',
    'list' => array('a', 'b', 5 => 'c', 'd'),
    'min' => [
        'numeric' => 'The :attribute field must be at least :min.',
        'string' => 'The :attribute field must be at least :min characters.',
    ],
];
PHP
cat > "$L/lang/de/auth.php" <<'PHP'
<?php
return [
    'failed' => 'Diese Kombination existiert nicht.',
    'throttle' => 'Zu viele Versuche. Bitte in :minutes Minuten erneut versuchen.',
    'greeting' => 'Hallo, :Name!',
    'long' => 'Teil eins :COUNT',
    'apples' => '{0} Keine Äpfel|{1} Ein Apfel|[2,19] :count Äpfel|[20,*] :count viele Äpfel',
    'pears' => 'eine Birne|viele Birnen',
    'list' => ['a', 'b', 5 => 'c'],
    'min' => ['numeric' => 'Das Feld :attribute muss mindestens :min sein.'],
    'extra_one' => 'zusätzlich',
];
PHP
cat > "$L/lang/fr/auth.php" <<'PHP'
<?php
return [
    'failed' => env('AUTH_FAILED', 'Identifiants incorrects.'),
];
PHP
printf '<?php return ["only" => "vendor"];\n' > "$L/lang/vendor/pkg/en/messages.php"
printf '{"Welcome, :name": "Willkommen, :name", "Bye": "Tschüss", "Only in de": "Nur hier"}\n' > "$L/lang/de.json"
printf '{"Welcome, :name": "Bienvenue", "Bye": "Au revoir"}\n' > "$L/lang/fr.json"
check "laravel: a key missing from a nested PHP array is named with its full path" "$L" 1 -- '  de  missing  auth.min.string'
check "laravel: an extra key is named" "$L" 1 -- '  de  extra  auth.extra_one'
check "laravel: a renamed :placeholder is a mismatch" "$L" 1 -- '  de  placeholder  auth.throttle  en: :seconds  de: :minutes'
check "laravel: a placeholder dropped from every plural segment is a mismatch" "$L" 1 -- '  de  placeholder  auth.pears  en: :count  de: (none)'
check "laravel: an unparseable PHP file is reported with its line" "$L" 1 -- \
  "  fr  unparsed  lang/fr/auth.php:3: unsupported expression \"env('AUTH_FAILED'"
check "laravel JSON: the key is the base string when the base has no JSON file" "$L" 1 -- \
  '  fr  placeholder  "Welcome, :name"  en: :name  fr: (none)'
check "laravel JSON: a key one translation has is missing from another" "$L" 1 -- '  fr  missing  "Only in de"'
refute "laravel: :Name and :COUNT are the same placeholder as :name and :count" "$L" 'auth.greeting'
refute "laravel: :COUNT after a literal concatenation" "$L" 'auth.long'
refute "laravel: a different plural interval set with the same placeholders is silent" "$L" 'auth.apples'
check "laravel: an auto key after an explicit int key continues from it, in array() and []" "$L" 1 -- '  de  missing  auth.list.6'
refute "laravel: an unparsed file is not guessed into missing keys" "$L" '  fr  missing  auth.'
refute "laravel: lang/vendor/ is not a locale" "$L" 'vendor'
refute "laravel JSON: a translated key with the same placeholders is silent" "$L" '"Bye"'

# The nearest silent input: casing variants, a plural with fewer segments, array() against [].
P="$T/parity"; mkdir -p "$P/lang/en" "$P/lang/de"
printf "<?php\nreturn ['a' => ':Count apple|:count apples', 'b' => ['c' => 'Hi :NAME']];\n" > "$P/lang/en/m.php"
printf "<?php\nreturn array('a' => ':count Apfel', 'b' => array('c' => 'Hallo :name',),);\n?>\n" > "$P/lang/de/m.php"
printf '{"Hi :name": "Hallo :Name"}\n' > "$P/lang/de.json"
check "laravel: parity exits 0 and says so" "$P" 0 -- '  parity' 'i18n_parity: 0 finding(s) in 1 layout(s); exit 0'

# laravel-vue-i18n's Vite plugin writes lang/php_<locale>.json; they are not locales.
X="$T/vuei18n"; mkdir -p "$X/lang/en" "$X/lang/de"
printf "<?php return ['failed' => 'x'];\n" > "$X/lang/en/auth.php"; cp "$X/lang/en/auth.php" "$X/lang/de/auth.php"
printf '{"auth.failed": "x"}\n' > "$X/lang/php_en.json"; cp "$X/lang/php_en.json" "$X/lang/php_de.json"
check "laravel: generated lang/php_<locale>.json files are skipped" "$X" 0 -- 'base en  locales: de, en' '  parity'

# Laravel 11+ ships en inside the framework: a tree with no base PHP file draws no extra-file per translation file.
K="$T/l11"; mkdir -p "$K/lang/de"
printf "<?php return ['required' => 'Das Feld :attribute ist erforderlich.'];\n" > "$K/lang/de/validation.php"
printf '{"Log in": "Log in"}\n' > "$K/lang/en.json"; printf '{"Log in": "Anmelden"}\n' > "$K/lang/de.json"
check "laravel: a base with lang/en.json and no PHP file compares the JSON and stays silent on PHP" "$K" 0 -- '  parity'
rm "$K/lang/en.json"
check "laravel: lang/de.json beside lang/de/*.php with no en is no base locale" "$K" 2 -- \
  "  base-missing  no 'en' locale here; pass --base-locale with one of: de"

# PHP escapes, cross-checked against PHP 8.5.12 on 2026-11-08: each decoded key exists only in de, so a wrong decode renames the finding.
E="$T/escapes"; mkdir -p "$E/lang/en" "$E/lang/de"
printf "<?php\nreturn ['plain' => 'x'];\n" > "$E/lang/en/esc.php"
cat > "$E/lang/de/esc.php" <<'PHP'
<?php
return [
    'plain' => 'x',
    "hex\x41" => 'x',
    "oct\102" => 'x',
    "uni\u{43}" => 'x',
    "dollar\$x" => 'x',
    'quote\'s' => 'x',
];
PHP
check 'laravel escape: "\x41" is A' "$E" 1 -- '  de  extra  esc.hexA'
check 'laravel escape: "\102" is B' "$E" 1 -- '  de  extra  esc.octB'
check 'laravel escape: "\u{43}" is C' "$E" 1 -- '  de  extra  esc.uniC'
check 'laravel escape: "\$x" is $x, not interpolation' "$E" 1 -- '  de  extra  esc.dollar$x'
check "laravel escape: 'quote\\'s' is quote's" "$E" 1 -- "  de  extra  esc.quote's"

# Laravel JSON with a base file: the base value is the reference string, and a key outside it is not extra.
J="$T/ljson"; mkdir -p "$J/lang"
printf '{"auth.welcome": "Welcome, :name"}\n' > "$J/lang/en.json"
printf '{"auth.welcome": "Willkommen", "Spare": "frei"}\n' > "$J/lang/de.json"
check "laravel JSON: the base file's value, not its key, is the reference string" "$J" 1 -- \
  '  de  placeholder  "auth.welcome"  en: :name  de: (none)'
refute "laravel JSON: a translation key outside the base file is not extra" "$J" '"Spare"'

# Shapes the parser refuses: each is reported, never read as an empty or partial array.
U="$T/unparsed"; mkdir -p "$U/lang/en" "$U/lang/de"
printf "<?php\nreturn ['a' => 'x', 'b' => 'y', 'c' => 'z', 'd' => 'w', 'e' => 'v'];\n" > "$U/lang/en/m.php"
cp "$U/lang/en/m.php" "$U/lang/de/m.php"
printf '<?php\nreturn ["a" => <<<EOT\nx\nEOT\n];\n' > "$U/lang/en/heredoc.php"
printf '<?php\nreturn ["a" => "Hi $name"];\n' > "$U/lang/en/interp.php"
printf '<?php\nreturn ["a" => __("x")];\n' > "$U/lang/en/call.php"
printf '<?php\nreturn array_merge(require __DIR__."/x.php", []);\n' > "$U/lang/en/merge.php"
printf '<?php\n$x = ["a" => "b"];\nreturn $x;\n' > "$U/lang/en/var.php"
printf '%s\n' '<?php' 'return ["a" => "\u{110000}"];' > "$U/lang/en/uesc.php"
for f in heredoc interp call merge var uesc; do cp "$U/lang/en/$f.php" "$U/lang/de/$f.php"; done
check "laravel: a heredoc is unparsed" "$U" 1 -- '  de  unparsed  lang/de/heredoc.php:2: ' '  en  unparsed  lang/en/heredoc.php:2: '
check "laravel: interpolation in a double-quoted string is unparsed" "$U" 1 -- \
  '  en  unparsed  lang/en/interp.php:2: variable interpolation in a double-quoted string'
check "laravel: a function call is unparsed" "$U" 1 -- '  en  unparsed  lang/en/call.php:2: unsupported expression'
check "laravel: a computed return is unparsed" "$U" 1 -- '  en  unparsed  lang/en/merge.php:2: unsupported expression'
check "laravel: a variable returned is unparsed" "$U" 1 -- '  en  unparsed  lang/en/var.php:2: expected `return [...]`'
check "laravel: a \\u{} escape past U+10FFFF is unparsed, not a traceback" "$U" 1 -- '  en  unparsed  lang/en/uesc.php:2: invalid \u escape'
check "laravel: an identical parseable pair beside them stays silent" "$U" 1 -- 'i18n_parity: 12 finding(s) in 1 layout(s); exit 1'

# --- i18next: nested keys, _one/_other families, {{var}} forms, $t() nesting ---
N="$T/i18next"; mkdir -p "$N/public/locales/en" "$N/public/locales/de" "$N/public/locales/ru" "$N/public/locales/fr"
cat > "$N/public/locales/en/common.json" <<'J'
{"greet": "Hello {{name}}", "shout": "HEY {{- name, uppercase}}", "item_one": "{{count}} item", "item_other": "{{count}} items",
 "nav": {"home": "Home", "about": "About"}, "link": "See $t(nav.home)", "button_one": "no _other, so not a family"}
J
cat > "$N/public/locales/ru/common.json" <<'J'
{"greet": "Привет {{ name }}", "shout": "ЭЙ {{-name}}", "item_one": "{{count}} предмет", "item_few": "{{count}} предмета",
 "item_many": "{{count}} предметов", "item_other": "{{count}} предмета", "nav": {"home": "Главная", "about": "О нас"},
 "link": "См. $t(nav.home)", "button_one": "x"}
J
cat > "$N/public/locales/de/common.json" <<'J'
{"greet": "Hallo {{user}}", "shout": "HEY {{name}}", "item_one": "ein Ding", "item_other": "{{count}} Dinge", "nav": {"home": "Start"},
 "link": "Siehe Start", "legacy": "alt", "button_one": "x", "button_few": "y"}
J
cat > "$N/public/locales/fr/common.json" <<'J'
{"greet": "Salut {{name}}", "shout": "{{name}}", "item_one": "{{count}} truc", "nav": {"home": "Accueil", "about": "A propos"},
 "link": "$t(nav.home)", "button_one": "x"}
J
check "i18next: a nested key missing" "$N" 1 -- '  de  missing  common:nav.about'
check "i18next: an extra key" "$N" 1 -- '  de  extra  common:legacy'
check "i18next: a renamed {{var}} is a mismatch" "$N" 1 -- '  de  placeholder  common:greet  en: {{name}}  de: {{user}}'
check "i18next: a dropped \$t() nesting is a mismatch" "$N" 1 -- '  de  placeholder  common:link  en: $t(nav.home)  de: (none)'
check "i18next: a family with no _other is missing, its lone form extra" "$N" 1 -- \
  '  fr  missing  common:item_{one,other}' '  fr  extra  common:item_one'
refute "i18next: ru's one/few/many/other is the same family as en's one/other" "$N" '  ru  '
refute "i18next: {{- name, uppercase}} and {{ name }} are {{name}}" "$N" 'common:shout'
refute "i18next: a placeholder in any family member satisfies the family" "$N" 'common:item_{one,other}  en:'
check "i18next: a _one key without its _other is a plain key, so a sibling _few is extra" "$N" 1 -- '  de  extra  common:button_few'

# --- vue-i18n: {var}, {0} lists, @:linked, | plurals, {'literal'} ---
V="$T/vue"; mkdir -p "$V/src/locales"
cat > "$V/src/locales/en.json" <<'J'
{"hi": "Hi {name}", "cars": "no car | one car | {count} cars", "msg": {"dio": "DIO", "world": "the world", "linked": "@:msg.dio @:msg.world !!!"},
 "list": "{0} and {1}", "at": "{'@'} sign", "gone": "x", "ref": "see @:msg.dio"}
J
cat > "$V/src/locales/de.json" <<'J'
{"hi": "Hallo {user}", "cars": "kein Auto | {count} Autos", "msg": {"dio": "DIO", "world": "die Welt", "linked": "@.upper:msg.dio @:msg.world"},
 "list": "{1} und {0}", "at": "{'#'} Zeichen", "ref": "siehe DIO"}
J
check "vue-i18n: a missing key" "$V" 1 -- '  de  missing  gone'
check "vue-i18n: a renamed {var} is a mismatch" "$V" 1 -- '  de  placeholder  hi  en: {name}  de: {user}'
check "vue-i18n: a dropped @:linked message is a mismatch" "$V" 1 -- '  de  placeholder  ref  en: @:msg.dio  de: (none)'
refute "vue-i18n: fewer | segments with the same {count} is silent" "$V" 'cars'
refute "vue-i18n: a link modifier and list order are not mismatches" "$V" 'linked'
refute "vue-i18n: list placeholders in another order are silent" "$V" '  list'
refute "vue-i18n: a {'literal'} is not a placeholder" "$V" '  at'

# --- package.json decides the format of a JSON tree the path alone would call vue-i18n ---
C="$T/cra"; mkdir -p "$C/src/locales/en" "$C/src/locales/ru"
printf '{"item_one":"{{count}} a","item_other":"{{count}} b"}\n' > "$C/src/locales/en/translation.json"
printf '{"item_one":"{{count}} a","item_few":"{{count}} c","item_many":"{{count}} d","item_other":"{{count}} b"}\n' > "$C/src/locales/ru/translation.json"
check "format: src/locales without a package.json reads as vue-i18n, so ru's extra forms are keys" "$C" 1 -- \
  '  ru  extra  translation:item_few'
printf '{"dependencies":{"react-i18next":"^15.0.0"}}\n' > "$C/package.json"
check "format: a react-i18next dependency makes the same tree i18next, at parity" "$C" 0 -- \
  'i18next  src/locales/  base en  locales: en, ru  (format from package.json)' '  parity'

# --- exits 2 and 3, JSON ---
mkdir -p "$T/empty" "$T/yaml/src/locales" "$T/vendoronly/lang/vendor/pkg/en"
printf 'hi: x\n' > "$T/yaml/src/locales/en.yaml"
printf '<?php return ["a" => "b"];\n' > "$T/vendoronly/lang/vendor/pkg/en/m.php"
check "no locale files: an empty project exits 3" "$T/empty" 3 -- 'i18n_parity: no locale files under'
check "no locale files: YAML is not read" "$T/yaml" 3
check "no locale files: lang/vendor/ alone exits 3" "$T/vendoronly" 3
B="$T/nobase"; mkdir -p "$B/lang/de" "$B/lang/fr"
printf '<?php return ["a" => "x :n"];\n' > "$B/lang/de/m.php"; printf '<?php return ["a" => "y"];\n' > "$B/lang/fr/m.php"
printf '{"Hi": "Salut"}\n' > "$B/lang/fr.json"
check "base locale absent everywhere exits 2 and names the locales, a lang/<locale>.json beside the PHP included" "$B" 2 -- \
  "  base-missing  no 'en' locale here; pass --base-locale with one of: de, fr"
check "--base-locale picks another base" "$B" 1 --base-locale de -- '  fr  placeholder  m.a  de: :n  fr: (none)'
out=$(python3 -B "$IP" --bogus 2>&1); rc=$?
{ [ "$rc" -eq 2 ] && ! grep -q Traceback <<<"$out"; } && pass=$((pass + 1)) || { echo "FAIL  an unknown flag exits 2 (rc=$rc)"; fail=$((fail + 1)); }
out=$(python3 -B "$IP" "$T/absent" 2>&1); rc=$?
{ [ "$rc" -eq 2 ] && grep -qF 'not a directory' <<<"$out"; } && pass=$((pass + 1)) || { echo "FAIL  a missing root exits 2 (rc=$rc): $out"; fail=$((fail + 1)); }
out=$(python3 -B "$IP" "$L" --json 2>&1); rc=$?
got=$(python3 -c 'import json,sys; r=json.loads(sys.argv[1]); print(r["exit"], " ".join(sorted({f["kind"] for l in r["layouts"] for f in l["findings"]})))' "$out" 2>&1)
[ "$rc" -eq 1 ] && [ "$got" = "1 extra missing placeholder unparsed" ] && pass=$((pass + 1)) \
  || { echo "FAIL  --json carries the exit and every finding kind (rc=$rc): $got"; fail=$((fail + 1)); }
out=$(python3 -B "$IP" "$T/empty" --json 2>&1); rc=$?
got=$(python3 -c 'import json,sys; r=json.loads(sys.argv[1]); print(r["exit"], len(r["layouts"]))' "$out" 2>&1)
[ "$rc" -eq 3 ] && [ "$got" = "3 0" ] && pass=$((pass + 1)) || { echo "FAIL  --json on no locale files (rc=$rc): $got"; fail=$((fail + 1)); }

printf '\ni18n-parity: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
