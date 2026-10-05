#!/usr/bin/env bash
# Pins scan.sh's elision deny: a PreToolUse write that replaces existing code with a placeholder
# comment (`// ... existing code ...`) is refused at most twice per file, and nothing benign is except two
# stated refusals, each with a line removed: placeholder text in a string the tracker misreads, and prose an
# ellipsis opens with a listed phrase. A placeholder the deny lets through draws one PostToolUse warning, and a
# kept one draws none.
# Misses: the host's userConfig export itself — CLAUDE_PLUGIN_OPTION_* is set by hand here.
set -u
PLUGIN=$(cd "$(dirname "$0")/../.." && pwd) || exit 1
HOOK="$PLUGIN/hooks/scan.sh"
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }
command -v git >/dev/null 2>&1 || { echo "SKIP: git not found"; exit 0; }
FX=$(mktemp -d) || exit 1
trap 'rm -rf "$FX"' EXIT
unset CLAUDE_PLUGIN_DATA CLAUDE_PROJECT_DIR CC_REMIND CC_COMMENT_GUARD CC_ELISION_GUARD \
  CLAUDE_PLUGIN_OPTION_CC_REMIND CLAUDE_PLUGIN_OPTION_CC_COMMENT_GUARD CLAUDE_PLUGIN_OPTION_CC_ELISION_GUARD
rc=0; n=0; R=""

fresh() { n=$((n + 1)); R="$FX/repo$n"; mkdir -p "$R/src" && git -C "$R" init -q; }
put() { mkdir -p "$(dirname "$R/$1")" && printf '%s\n' "$2" > "$R/$1"; }
hook() { # event tool tool_input-json -> the hook's stdout
  jq -nc --arg c "$R" --arg e "$1" --arg t "$2" --argjson i "$3" \
    '{hook_event_name:$e,cwd:$c,session_id:"elision",transcript_path:"/t/elision.jsonl",tool_name:$t,tool_input:$i}' \
    | bash "$HOOK" 2>/dev/null
}
pre() { hook PreToolUse "$@"; }
post() { hook PostToolUse "$@"; }
write() { pre Write "$(jq -nc --arg f "$R/$1" --arg s "$2" '{file_path:$f,content:$s}')"; }
edit() { pre Edit "$(jq -nc --arg f "$R/$1" --arg o "$2" --arg s "$3" '{file_path:$f,old_string:$o,new_string:$s}')"; }
post_write() { post Write "$(jq -nc --arg f "$R/$1" --arg s "$2" '{file_path:$f,content:$s}')"; }
post_edit() { post Edit "$(jq -nc --arg f "$R/$1" --arg o "$2" --arg s "$3" '{file_path:$f,old_string:$o,new_string:$s}')"; }
post_bash() { post Bash "$(jq -nc --arg c "$1" '{command:$c}')"; }
multiedit() {
  pre MultiEdit "$(jq -nc --arg f "$R/$1" --arg o1 "$2" --arg s1 "$3" --arg o2 "$4" --arg s2 "$5" \
    '{file_path:$f,edits:[{old_string:$o1,new_string:$s1},{old_string:$o2,new_string:$s2}]}')"
}
run_bash() { pre Bash "$(jq -nc --arg c "$1" '{command:$c}')"; }
heredoc() { printf '%s\n%s\nEOF' "$1 <<'EOF'" "$2"; }
reason() { printf '%s' "$1" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null; }
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 — $2"; rc=1; }
denies() { # label output placeholder [suffix]
  case "$(reason "$2")" in
    "elision-guard:"*"$3"*"Blocked at most twice per file."*"CC_ELISION_GUARD=off disables this block for the session.${4:-}") pass "$1" ;;
    *) fail "$1" "want an elision deny naming '$3', got: ${2:-<silent>}" ;;
  esac
}
silent() { # label output
  if [ -z "$2" ]; then pass "$1"; else fail "$1" "want silence, got: $2"; fi
}
warns() { # label pre-output post-output placeholder
  local w; w=$(printf '%s' "$3" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
  case "$2|$w" in
    "|elision-guard:"*"\"$4\""*"Restore the omitted code"*) pass "$1" ;;
    *) fail "$1" "want no deny then a warning naming '$4', got [${2:-<silent>}] then [${3:-<silent>}]" ;;
  esac
}
unwarned() { # label post-output
  case "$2" in *elision-guard*) fail "$1" "want no elision warning, got: $2" ;; *) pass "$1" ;; esac
}

BASE='export function total(items: number[]): number {
  let sum = 0;
  for (const item of items) sum += item;
  return sum;
}

export function average(items: number[]): number {
  return items.length ? total(items) / items.length : 0;
}'
PH='// ... existing code ...'
ELIDED="export function total(items: number[]): number {
  let sum = 0;
  for (const item of items) sum += item;
  return sum;
}

$PH"
AVG='  return items.length ? total(items) / items.length : 0;'

fresh; put src/stats.ts "$BASE"
denies "write over existing file adds elision -> deny" "$(write src/stats.ts "$ELIDED")" "$PH"
put src/sum.ts "$BASE"
denies "write over existing file adds elision -> deny: unicode ellipsis" \
  "$(write src/sum.ts "${ELIDED%"$PH"}// … rest of the file unchanged")" "// … rest of the file unchanged"
put src/mean.ts "$BASE"
denies "write over existing file adds elision -> deny: parenthesised" \
  "$(write src/mean.ts "${ELIDED%"$PH"}// (... existing code ...)")" "// (... existing code ...)"
put src/median.ts "$BASE"
denies "write over existing file adds elision -> deny: trailing ellipsis" \
  "$(write src/median.ts "${ELIDED%"$PH"}// rest of the file unchanged ...")" "// rest of the file unchanged ..."

fresh; put src/stats.ts "$BASE"
denies "edit adds elision -> deny" "$(edit src/stats.ts "$AVG" '  // ... previous implementation ...')" \
  "// ... previous implementation ..."

fresh; put src/stats.ts "$BASE"
denies "multiedit adds elision -> deny" "$(multiedit src/stats.ts \
  'for (const item of items) sum += item;' 'for (const item of items) sum += Number(item);' \
  "$AVG" '  /* ... other methods ... */')" "/* ... other methods ... */"

fresh; put src/stats.ts "$BASE"
denies "multiedit with one absent old_string is judged by old/new" "$(multiedit src/stats.ts \
  'let sum = 0;' 'let sum: number = 0;' \
  'return items.reduce((a, b) => a + b, 0);' "  $PH")" "$PH"

fresh; put src/app.ts "$BASE"; put src/lib.ts "$BASE"
denies "overwriting heredoc -> deny" "$(run_bash "$(heredoc 'cat > src/app.ts' "$ELIDED")")" "$PH" \
  " Written by a Bash command: app.ts."
denies "overwriting heredoc -> deny: tee" "$(run_bash "$(heredoc 'tee src/lib.ts' "$ELIDED")")" "$PH" \
  " Written by a Bash command: lib.ts."

fresh; put src/app.ts "$BASE"
silent "append heredoc is never denied" "$(run_bash "$(heredoc 'cat >> src/app.ts' "$PH")")"
silent "append heredoc is never denied: tee -a" "$(run_bash "$(heredoc 'tee -a src/app.ts' "$PH")")"

fresh; put src/App.tsx 'export function App({ items }: Props) {
  return (
    <main>
      <Header />
      <List items={items} />
    </main>
  );
}'
denies "jsx markup elision -> deny" "$(write src/App.tsx 'export function App({ items }: Props) {
  return (
    <main>
      {/* ... rest of the component ... */}
    </main>
  );
}')" "{/* ... rest of the component ... */}"

fresh; put src/Card.vue '<template>
  <article class="card">
    <h2>{{ title }}</h2>
    <p>{{ body }}</p>
  </article>
</template>'
denies "vue markup elision -> deny" "$(write src/Card.vue '<template>
  <article class="card">
    <!-- ... rest of the component -->
  </article>
</template>')" "<!-- ... rest of the component -->"

fresh; put src/Panel.tsx 'export function Panel({ title }: PanelProps) {
  return (
    <section>
      <h2>{title}</h2>
      <p>Totals are summed per request.</p>
    </section>
  );
}'
denies "jsx markup spec example -> deny" "$(write src/Panel.tsx 'export function Panel({ title }: PanelProps) {
  return (
    <section>
      {/* ... existing JSX ... */}
    </section>
  );
}')" "{/* ... existing JSX ... */}"

fresh; put src/List.vue '<template>
  <ul class="list">
    <li v-for="item in items" :key="item.id">{{ item.name }}</li>
  </ul>
</template>'
denies "vue rest of the template -> deny" "$(write src/List.vue '<template>
  <ul class="list">
    <!-- ... rest of the template -->
  </ul>
</template>')" "<!-- ... rest of the template -->"

fresh; put src/stats.ts "$ELIDED"
silent "kept elision on disk -> allow" "$(write src/stats.ts "$ELIDED
export const zero = 0;")"

fresh; put src/stats.ts "$ELIDED"
silent "edit old_string carries it -> allow" "$(edit src/stats.ts "$PH" "$PH
export const zero = 0;")"

fresh; put src/Field.tsx 'export function Field({ label }: FieldProps) {
  return <input aria-label={label} />;
}'
silent "rest is forwarded is never judged" "$(write src/Field.tsx 'export function Field({ label, ...rest }: FieldProps) {
  // ...rest is forwarded to <input>
  return <input aria-label={label} {...rest} />;
}')"

fresh; put src/merge.ts 'export function merge(a: Settings, b: Partial<Settings>): Settings {
  return Object.assign({}, a, b);
}'
silent "example doc line is never judged" "$(write src/merge.ts '/**
 * Merges partial settings over the defaults.
 * @example
 * // ... existing code ...
 * const s = merge(defaults, { theme: "dark" });
 */
export function merge(a: Settings, b: Partial<Settings>): Settings {
  return { ...a, ...b };
}')"

fresh; put src/strip.ts 'export function strip(reply: string): string {
  return reply.trim();
}'
silent "doc-comment usage line is never judged" "$(write src/strip.ts '/**
 * Drops a placeholder line such as
 *   // ... existing code ...
 * from a model reply.
 */
export function strip(reply: string): string {
  return reply.replace(PLACEHOLDER, "");
}')"
put src/Strip.cs 'public static class Reply {
    public static string Strip(string reply) => reply.Trim();
}'
silent "doc-comment usage line is never judged: triple-slash" "$(write src/Strip.cs 'public static class Reply {
    /// Drops a placeholder line such as
    ///     // ... rest of the class ...
    /// from a model reply.
    public static string Strip(string reply) => Placeholder.Replace(reply, "");
}')"
put src/calc.ts 'export function calc(x: number): number {
  return x * 2;
}'
case "$(reason "$(write src/calc.ts '/**
 * Doubles the input.
 * // const old = compute(x);
 */
export function calc(x: number): number {
  return x * 2;
}')")" in
  comment-discipline:*) pass "comment-discipline still denies commented-out code in a doc block" ;;
  *) fail "comment-discipline still denies commented-out code in a doc block" "no comment deny" ;;
esac
put src/strip.py 'def strip(reply):
    return reply.strip()'
silent "doc-comment usage line is never judged: python docstring" "$(write src/strip.py 'def strip(reply):
    """Drop a placeholder line such as

        # ... existing code ...

    from a model reply.
    """
    return PLACEHOLDER.sub("", reply)')"

fresh; put src/store.py 'class Store:
    def load(self, key):
        return self.data[key]'
silent "python ellipsis stub is never judged" "$(write src/store.py 'from typing import Protocol


class Store(Protocol):
    def load(self, key: str) -> bytes: ...

    def save(self, key: str, value: bytes) -> None: ...  # keep existing value on conflict')"

fresh; put src/merge.go 'package merge

func Append(existing []string, rest []string) []string {
	return append(existing, rest...)
}'
silent "go variadic is never judged" "$(write src/merge.go 'package merge

func Append(existing []string, rest ...string) []string {
	return append(existing, rest...) // keep existing order
}')"

fresh; put src/options.js 'export function withDefaults(options) {
  return Object.assign({}, defaults, options);
}'
silent "js spread is never judged" "$(write src/options.js 'export function withDefaults(options) {
  // spreads ...defaults first, so omitted keys keep the existing value
  return { ...defaults, ...options };
}')"

fresh; put src/hints.ts 'export const HINT = "";'
silent "string literal is never judged" "$(write src/hints.ts 'export const HINT = "// ... existing code ...";
export const NOTE = `... rest of the file unchanged ...`;')"

fresh; put src/truncate.ts 'export function truncate(text: string, max: number): string {
  return text.slice(0, max);
}'
silent "quoted ellipsis in a prose comment is never judged" "$(write src/truncate.ts '// The "..." suffix marks omitted text.
export function truncate(text: string, max: number): string {
  return text.length > max ? text.slice(0, max) + "..." : text;
}')"
put src/truncate.py 'def truncate(text, limit):
    return text[:limit]'
silent "quoted ellipsis in a prose comment is never judged: python" "$(write src/truncate.py 'def truncate(text, limit):
    # Append "..." when the rest of the line is omitted.
    return text[:limit] + "..." if len(text) > limit else text')"
put src/clip.ts 'export function clip(text: string, max: number): string {
  return text.slice(0, max);
}'
silent "quoted ellipsis in a prose comment is never judged: mid-sentence ellipsis" "$(write src/clip.ts 'export function clip(text: string, max: number): string {
  // Text past max is omitted and ... is appended.
  return text.length > max ? text.slice(0, max) + "..." : text;
}')"
put src/reply.ts 'export function reply(body: string): string {
  return body.trim();
}'
silent "quoted ellipsis in a prose comment is never judged: quoted placeholder" "$(write src/reply.ts 'export function reply(body: string): string {
  // Never emit "// ... existing code ..." here.
  return body.trimEnd();
}')"
put src/view.ts 'export function view(props: Props): Node {
  return render(props);
}'
silent "quoted ellipsis in a prose comment is never judged: elided call arguments" "$(write src/view.ts 'export function view(props: Props): Node {
  // Same as above, but through render(...)
  return render({ ...defaults, ...props });
}')"

# Contract: an ellipsis that only closes a comment counts only after a code noun, and no doc-comment line counts.
TOT='export function total(items: number[]): number {
  return items.reduce((a, b) => a + b, 0);
}'
noted() { printf 'export function total(items: number[]): number {\n%s\n  return items.reduce((sum, item) => sum + item, 0);\n}' "$1"; }
pn=0
prose() { pn=$((pn + 1)); put "src/total$pn.ts" "$TOT"; silent "$1" "$(write "src/total$pn.ts" "$2")"; }
fresh
prose "prose ending in an ellipsis is never judged" "$(noted '  // If the key is omitted...')"
prose "prose ending in an ellipsis is never judged: optional fields" "$(noted '  // Optional fields are omitted...')"
prose "prose ending in an ellipsis is never judged: keep existing" "$(noted '  // Keep existing behaviour for now...')"
prose "prose ending in an ellipsis is never judged: same as above" "$(noted '  // Same as above...')"
prose "prose ending in an ellipsis is never judged: previous implementation" \
  "$(noted '  // Retry; previous implementation dropped errors...')"
prose "prose ending in an ellipsis is never judged: block comment" "$(noted '  /* Fields not listed are omitted... */')"
prose "prose ending in an ellipsis is never judged: replaced with an ellipsis" \
  "$(noted '  // Text past max is omitted and replaced with ...')"
prose "prose ending in an ellipsis is never judged: unicode ellipsis" "$(noted '  // When text is omitted, append …')"
prose "prose ending in an ellipsis is never judged: doc usage line" "/**
 * Sums the items; a caller never elides it as
 *   ... existing code ...
 */
$(noted '')"
prose "prose ending in an ellipsis is never judged: doc example label" "/**
 * Sums the items.
 * Example: // ... existing code ...
 */
$(noted '')"
prose "bracketed placeholder is a stated miss" "$(noted '  // [...] existing code')"
prose "bracketed placeholder is a stated miss: closing" "$(noted '  // existing code (...)')"
put src/lazy.ts "$TOT"
denies "prose opening with an ellipsis and a listed phrase is a stated refusal" \
  "$(write src/lazy.ts "$(noted '  // ... and the rest of the file is parsed lazily')")" \
  "// ... and the rest of the file is parsed lazily"

fresh; put NOTES.md '# Notes

Totals are summed per request.'
silent "markdown is never judged" "$(write NOTES.md '# Notes

```ts
// ... existing code ...
```')"

fresh; mkdir -p "$R/.claude-plugin"; printf '{}\n' > "$R/.claude-plugin/marketplace.json"
GUARD='#!/bin/bash
input=$(cat)
printf "%s" "$input" | jq -r .tool_name
exit 0'
put plugins/demo/hooks/guard.sh "$GUARD"; put plugins/demo/hooks/other.sh "$GUARD"
denies "path-exempt hook path is still judged" "$(write plugins/demo/hooks/guard.sh '#!/bin/bash
input=$(cat)
# ... existing code ...
exit 0')" "# ... existing code ..."
silent "path-exempt hook path is still judged: the comment deny stays exempt there" \
  "$(write plugins/demo/hooks/other.sh "$GUARD
# exit 0
exit 0")"

fresh; put src/api.ts "$BASE"
silent "generated file is exempt" "$(write src/api.ts "// @generated by openapi-codegen. Do not edit.
$ELIDED")"

fresh; awk 'BEGIN { for (i = 0; i < 45000; i++) printf "export const v%d = %d;\n", i, i }' > "$R/src/big.ts"
silent "file over size cap is not compared" "$(write src/big.ts "$ELIDED")"

fresh; put src/stats.ts "$BASE"
NOISY="$ELIDED
// increment the counter
counter++;"
denies "both denies: elision alone" "$(write src/stats.ts "$NOISY")" "$PH"
if [ -n "$(find "$R/.claude/comment-discipline" -name 'elision-blocked-*' 2>/dev/null)" ] \
   && [ -z "$(find "$R/.claude/comment-discipline" -name 'blocked-*' 2>/dev/null)" ]; then
  pass "both denies: elision alone: only the elision marker is spent"
else
  fail "both denies: elision alone: only the elision marker is spent" "$(find "$R/.claude" 2>/dev/null | tr '\n' ' ')"
fi
case "$(reason "$(export CC_ELISION_GUARD=off; write src/stats.ts "$NOISY")")" in
  comment-discipline:*) pass "both denies: elision alone: the same write draws the comment deny once elision is off" ;;
  *) fail "both denies: elision alone: the same write draws the comment deny once elision is off" "no comment deny" ;;
esac

fresh; put src/stats.ts "$BASE"
d1=$(write src/stats.ts "$ELIDED"); d2=$(write src/stats.ts "$ELIDED"); d3=$(write src/stats.ts "$ELIDED")
case "$(reason "$d1")|$(reason "$d2")|$d3" in
  elision-guard:*"|elision-guard:"*"|") pass "two elision denies then pass" ;;
  *) fail "two elision denies then pass" "want deny, deny, silence; got [$d1] [$d2] [$d3]" ;;
esac

fresh; put src/stats.ts "$BASE"
denies "comment guard off keeps elision deny" "$(export CC_COMMENT_GUARD=off; write src/stats.ts "$ELIDED")" "$PH"

fresh; put src/stats.ts "$BASE"
silent "elision guard off allows" "$(export CC_ELISION_GUARD=off; write src/stats.ts "$ELIDED")"

fresh
d=$(write src/fresh.ts "$ELIDED"); put src/fresh.ts "$ELIDED"
warns "new file elision -> warn, no deny" "$d" "$(post_write src/fresh.ts "$ELIDED")" "$PH"
unwarned "new file elision -> warn, no deny: the warning is one-shot" "$(post_write src/fresh.ts "$ELIDED")"
d=$(write src/gone.ts "$ELIDED")
unwarned "new file elision -> warn, no deny: a marker its write never used is dropped unsaid" \
  "$(post_write src/gone.ts 'export const all = (xs: number[]) => [...xs];')"
MADE=$(heredoc 'cat > src/made.ts' "$ELIDED")
d=$(run_bash "$MADE"); put src/made.ts "$ELIDED"
warns "new file elision -> warn, no deny: heredoc" "$d" "$(post_bash "$MADE")" "$PH"

fresh; put src/stats.ts "$BASE"
warns "ellipsis-only -> warn, no deny" "$(edit src/stats.ts "$AVG" '  // ...')" \
  "$(post_edit src/stats.ts "$AVG" '  // ...')" "// ..."

fresh; put src/stats.ts "$ELIDED"
KEPT="$ELIDED
export const zero = 0;"
d=$(write src/stats.ts "$KEPT"); put src/stats.ts "$KEPT"
if [ -z "$d" ]; then unwarned "kept elision -> no warning" "$(post_write src/stats.ts "$KEPT")"
else fail "kept elision -> no warning" "denied: $d"; fi
d=$(edit src/stats.ts "$PH" "$PH
export const one = 1;")
if [ -z "$d" ]; then unwarned "kept elision -> no warning: edit" "$(post_edit src/stats.ts "$PH" "$PH
export const one = 1;")"
else fail "kept elision -> no warning: edit" "denied: $d"; fi

fresh; put src/stats.ts "$BASE"
d1=$(write src/stats.ts "$ELIDED"); d2=$(write src/stats.ts "$ELIDED"); d3=$(write src/stats.ts "$ELIDED")
put src/stats.ts "$ELIDED"
case "$(reason "$d1")|$(reason "$d2")" in
  elision-guard:*"|elision-guard:"*) warns "third attempt passes and warns" "$d3" "$(post_write src/stats.ts "$ELIDED")" "$PH" ;;
  *) fail "third attempt passes and warns" "want two denies first, got [$d1] [$d2]" ;;
esac

fresh; put src/app.ts "$BASE"
silent "CC_ELISION_GUARD=off -> no elision deny" \
  "$(export CC_ELISION_GUARD=off; run_bash "$(heredoc 'cat > src/app.ts' "$ELIDED")")"

fresh; put src/stats.ts "$BASE"
d=$(export CC_ELISION_GUARD=off; write src/stats.ts "$ELIDED"); put src/stats.ts "$ELIDED"
warns "elision guard off still warns" "$d" "$(post_write src/stats.ts "$ELIDED")" "$PH"

fresh; put src/stats.ts "$BASE"
d=$(export CC_REMIND=off; write src/fresh.ts "$ELIDED"); put src/fresh.ts "$ELIDED"
w=$(export CC_REMIND=off; post_write src/fresh.ts "$ELIDED")
left=$(find "$R/.claude" -name 'elision-warn-*' 2>/dev/null)
if [ -z "$d$w$left" ]; then pass "CC_REMIND=off silences the elision warning"
else fail "CC_REMIND=off silences the elision warning" "got [$d] [$w], markers left: [$left]"; fi
denies "CC_REMIND=off silences the elision warning: the deny stays on" \
  "$(export CC_REMIND=off CC_COMMENT_GUARD=off; write src/stats.ts "$ELIDED")" "$PH"

fresh; put src/stats.ts "$BASE"
silent "userConfig off -> no elision deny" \
  "$(export CLAUDE_PLUGIN_OPTION_CC_ELISION_GUARD=false; write src/stats.ts "$ELIDED")"
case "$(reason "$(export CLAUDE_PLUGIN_OPTION_CC_ELISION_GUARD=false; write src/stats.ts "$NOISY")")" in
  comment-discipline:*) pass "userConfig off -> no elision deny: the comment deny stays on" ;;
  *) fail "userConfig off -> no elision deny: the comment deny stays on" "no comment deny" ;;
esac

# Contract: a placeholder line inside a multi-line string is text, so it is never judged; one after the string closes still is.
fresh; put src/snip.ts 'export const SNIPPET = "";'
silent "template literal elision text" "$(write src/snip.ts 'export const SNIPPET = `function demo() {
  // ... existing code ...
  return 1;
}`;')"

fresh; put src/detect.test.ts 'import { expect, it } from "vitest";
import { detect } from "./detect";

it("finds placeholders", () => {
  expect(detect("")).toBe(false);
});'
silent "vitest template literal is never judged" "$(edit src/detect.test.ts '  expect(detect("")).toBe(false);' '  expect(detect("")).toBe(false);
  expect(detect(`function a() {
  // ... existing code ...
}`)).toBe(true);')"

fresh; put src/prompt.ts 'export const PROMPT = "";'
silent "ts prompt template literal is never judged" "$(write src/prompt.ts 'export const PROMPT = `Return the whole file. Never stand in for code with a line like
// ... existing code ...
or the reply is rejected.`;')"

fresh; put src/prompt.py 'PROMPT = ""'
silent "python triple-quoted string is never judged" "$(write src/prompt.py 'PROMPT = """Return the whole file. Never stand in for code with a line like
# ... rest of the code unchanged ...
or the reply is rejected."""')"

fresh; put src/fixture.sh '#!/bin/bash
FIXTURE=""'
silent "shell quoted fixture is never judged" "$(write src/fixture.sh '#!/bin/bash
FIXTURE='"'"'total=0
# ... existing code ...
echo "$total"'"'"'
printf "%s\n" "$FIXTURE"')"
silent "shell quoted fixture is never judged: heredoc body" "$(write src/fixture.sh '#!/bin/bash
cat > out.sh <<'"'"'EOF'"'"'
total=0
# ... existing code ...
EOF')"

fresh; mkdir -p "$R/.claude-plugin"; printf '{}\n' > "$R/.claude-plugin/marketplace.json"
put plugins/demo/scripts/__tests__/demo.test.sh '#!/bin/bash
put src/a.sh '"'"'x=1
y=2'"'"'
echo done'
silent "harness fixture edit in a marketplace root is never judged" "$(edit plugins/demo/scripts/__tests__/demo.test.sh \
  "put src/a.sh 'x=1
y=2'" "put src/a.sh 'x=1
# ... rest of the file unchanged ...
y=2'")"

fresh; put src/after.ts "$BASE"
denies "placeholder after a closed template literal is still denied" "$(write src/after.ts 'export const NOTE = `first
second`;
// ... existing code ...')" "$PH"
put src/after.py 'NOTE = ""'
denies "placeholder after a closed triple quote is still denied" "$(write src/after.py 'NOTE = """first
second"""
# ... existing code ...')" "# ... existing code ..."
put src/after.sh '#!/bin/bash
NOTE=""'
denies "placeholder after a closed shell quote and heredoc is still denied" "$(write src/after.sh '#!/bin/bash
NOTE='"'"'first
second'"'"'
cat > out.txt <<EOF
$NOTE
EOF
# ... existing code ...')" "# ... existing code ..."

fresh; put src/Settings.php '<?php
function merge(array $defaults, array $store): array {
    return array_merge($defaults, $store);
}'
silent "ellipsis glued to a \$name is never judged" "$(write src/Settings.php '<?php
function merge(array $defaults, array $store): array {
    // The other fields come from ...$defaults
    return [...$defaults, ...$store];
}')"
put src/copy.js 'export const copy = (store) => Object.assign({}, store);'
silent "ellipsis glued to a \$name is never judged: js" "$(write src/copy.js 'export const copy = ($store) => {
  // Copies the other fields from ...$store
  return { ...$store };
};')"

fresh; put src/fixture.sh '#!/bin/bash
FIXTURE='"'"'a=1
echo done'"'"'
printf "%s\n" "$FIXTURE"'
silent "edit starting inside a shell string is never judged" "$(edit src/fixture.sh "echo done'" "# ... rest of the file unchanged ...
echo done'")"
put src/prompt.ts 'export const PROMPT = `Return the whole file.
Never stand in for code.`;'
silent "edit starting inside a template literal is never judged" "$(edit src/prompt.ts 'Never stand in for code.`;' '// ... existing code ...
Never stand in for code.`;')"
put src/prompt.py 'PROMPT = """Return the whole file.
Never stand in for code."""'
silent "edit starting inside a triple-quoted string is never judged" "$(edit src/prompt.py 'Never stand in for code."""' '# ... rest of the code unchanged ...
Never stand in for code."""')"
silent "edit closing a template then adding a placeholder is a stated miss" "$(edit src/prompt.ts 'Never stand in for code.`;' 'Never stand in for code.`;
// ... existing code ...')"

# Contract: an Edit is denied only when the file after it and its old/new strings both add a placeholder.
fresh; put src/prompt.ts 'import { z } from "zod";

export const EDIT_PROMPT = `Return the whole file. Never write
// ... existing code ...
in place of code.`;'
silent "edit near a regex read as a block comment is not denied" "$(edit src/prompt.ts 'import { z } from "zod";' 'import { z } from "zod";

const TRAILING = /\/*$/;
export const strict = (o: Options) => ({ ...o, strict: true });')"
put src/detect.test.ts 'import { expect, it } from "vitest";
import { detect } from "./detect";

const TRAILING = /\/*$/;

it("finds placeholders", () => {
  expect(detect("")).toBe(false);
});'
CASE_OLD='  expect(detect("")).toBe(false);'
CASE_NEW='  expect(detect("")).toBe(false);
  expect(detect(`function a() {
  // ... existing code ...
}`)).toBe(true);'
silent "edit adding placeholder text inside a template after a misread regex is not denied" \
  "$(edit src/detect.test.ts "$CASE_OLD" "$CASE_NEW")"
unwarned "allowed misread edit leaves no false warning" "$(post_edit src/detect.test.ts "$CASE_OLD" "$CASE_NEW")"
printf '%s\n' "$BASE" | awk '{ printf "%s\r\n", $0 }' > "$R/src/crlf.ts"
denies "crlf file edit replacing code with a placeholder is still denied" "$(edit src/crlf.ts 'export function average(items: number[]): number {
  return items.length ? total(items) / items.length : 0;
}' "$PH")" "$PH"
printf '%s\r\n' '#!/bin/bash' "FIXTURE='a=1" 'b=2' "echo done'" 'printf "%s\n" "$FIXTURE"' > "$R/src/crlf.sh"
silent "crlf shell fixture edit is not denied" "$(edit src/crlf.sh "b=2
echo done'" "# ... rest of the file unchanged ...
echo done'")"
printf '%s\r\n' 'export const PROMPT = `Return the whole file.' 'Do not shorten it.' 'Never stand in for code.`;' \
  > "$R/src/crlf-prompt.ts"
silent "crlf template edit is not denied" "$(edit src/crlf-prompt.ts 'Do not shorten it.
Never stand in for code.`;' "$PH
Never stand in for code.\`;")"

# Contract: code is lost only when a non-blank line of what the write replaces is gone.
fresh; put src/prompt.ts 'const TRAILING = /\/*$/;

export const PROMPT = `Return the whole file.
Never stand in for code.`;'
silent "misread regex above a template: appending a placeholder is not denied" \
  "$(edit src/prompt.ts 'Return the whole file.' "Return the whole file.
$PH")"
put src/Hint.tsx 'export const Hint = () => <p>Press the ` key to open the console.</p>;

export const PROMPT = `Return the whole file.
Never stand in for code.`;'
silent "lone backtick in jsx text above a template: appending is not denied" \
  "$(edit src/Hint.tsx 'Return the whole file.' "Return the whole file.
$PH")"
put src/strip.ts 'import { z } from "zod";'
silent "one edit adding a regex and a template with a placeholder is not denied" \
  "$(edit src/strip.ts 'import { z } from "zod";' 'import { z } from "zod";

const TRAILING = /\/*$/;
export const PROMPT = `Never write
// ... existing code ...
in place of code.`;')"
put src/stats.ts "$ELIDED"
silent "edit adding a placeholder line the file already holds is a stated miss" "$(edit src/stats.ts '  let sum = 0;
  for (const item of items) sum += item;
  return sum;' "  $PH")"
TRIM='const TRAILING = /\/*$/;
export const strip = (s: string) => s.replace(TRAILING, "");'
TRIMMED="$TRIM

export const PROMPT = \`Never write
$PH
in place of code.\`;"
put src/trim.ts "$TRIM"
silent "write adding placeholder text with nothing removed is not denied" "$(write src/trim.ts "$TRIMMED")"
put src/trim.ts "$TRIMMED"
unwarned "write adding placeholder text with nothing removed is not denied: nor warned" \
  "$(post_write src/trim.ts "$TRIMMED")"
put src/Prompt.php '<?php
function prompt(): string {
    return "Return the whole file.";
}'
denies "misread string with a removed line is a stated refusal" "$(write src/Prompt.php '<?php
function prompt(): string {
    return <<<EOT
Return the whole file. Never write
// ... existing code ...
in place of code.
EOT;
}')" "$PH"

fresh; put src/query.go 'package query

const Select = ""'
silent "go raw string is never judged" "$(write src/query.go 'package query

const Select = `SELECT id
// ... existing code ...
FROM t`')"
put src/Prompt.kt 'val prompt = ""'
silent "kotlin raw string is never judged" "$(write src/Prompt.kt 'val prompt = """Return the whole file.
// ... existing code ...
"""')"

put src/nest.ts 'export const S = "";'
silent "nested template inside \${} is never judged" "$(write src/nest.ts 'export const S = `a ${xs.map((x) => `
// ... existing code ...
`).join({ sep: "" }[0])} b
// ... rest of the file unchanged ...
`;')"
denies "placeholder after a nested template is still denied" "$(write src/nest.ts 'export const S = `a ${xs.map((x) => `
${x}
`)} b`;
// ... existing code ...')" "$PH"

put src/gen.sh '#!/bin/bash
echo start'
silent "heredoc body line '  EOF' does not end the heredoc" "$(write src/gen.sh '#!/bin/bash
cat > out.sh <<'"'"'EOF'"'"'
total=0
  EOF
# ... existing code ...
EOF')"
denies "placeholder after a <<- heredoc ended by a tab is still denied" "$(write src/gen.sh "#!/bin/bash
cat > out.sh <<-'EOF'
	total=0
	EOF
# ... existing code ...")" "# ... existing code ..."

fresh; put src/count.ts 'let counter = 0;
// ...
export function bump() {
  counter += 1;
}'
case "$(reason "$(edit src/count.ts '  counter += 1;' '  // ...
  // increment the counter
  counter++;')")" in
  comment-discipline:*) ;;
  *) fail "marker from a denied call never warns later" "want the comment deny on the first edit" ;;
esac
left=$(find "$R/.claude" -name 'elision-warn-*' 2>/dev/null)
if [ -z "$left" ]; then pass "marker from a denied call never warns later: the deny removes it"
else fail "marker from a denied call never warns later: the deny removes it" "left: $left"; fi
post_edit src/count.ts 'let counter = 0;' 'let counter = 1;' >/dev/null
d=$(edit src/count.ts '// ...
export function bump() {' '// ...
export function bump(): void {')
if [ -z "$d" ]; then unwarned "marker from a denied call never warns later" "$(post_edit src/count.ts '// ...
export function bump() {' '// ...
export function bump(): void {')"
else fail "marker from a denied call never warns later" "denied: $d"; fi
write src/left.ts "$ELIDED" >/dev/null
post_write src/left.ts 'export const none = 0;' >/dev/null
left=$(find "$R/.claude" -name 'elision-warn-*' 2>/dev/null)
if [ -z "$left" ]; then pass "marker from a denied call never warns later: a clean write consumes a sibling's leftover"
else fail "marker from a denied call never warns later: a clean write consumes a sibling's leftover" "left: $left"; fi

NEWPH='// ... rest of the file ...'
fresh; put src/stats.ts "$ELIDED
export const zero = 0;"
denies "deny names the new placeholder, not the kept one" "$(write src/stats.ts "$ELIDED
$NEWPH")" "$NEWPH"
d=$(write src/stats.ts "$ELIDED
// ..."); put src/stats.ts "$ELIDED
// ..."
warns "warning names the new placeholder, not the kept one" "$d" "$(post_write src/stats.ts "$ELIDED
// ...")" "// ..."

fresh
TWO="cat > src/one.ts <<'EOF'
$ELIDED
EOF
cat > src/two.ts <<'EOF'
$ELIDED
EOF"
d=$(run_bash "$TWO"); put src/one.ts "$ELIDED"; put src/two.ts "$ELIDED"
w=$(post_bash "$TWO" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
left=$(find "$R/.claude" -name 'elision-warn-*' 2>/dev/null)
case "$d|$w|$left" in
  "|elision-guard: one.ts"*"elision-guard: two.ts"*"|") pass "two heredoc files both warn, no marker left" ;;
  *) fail "two heredoc files both warn, no marker left" "got [$d] [$w], markers left: [$left]" ;;
esac

fresh; : > "$R/src/zero.ts"; put src/blank.ts '   '
d=$(write src/zero.ts "$ELIDED"); put src/zero.ts "$ELIDED"
warns "empty existing file -> warn, no deny" "$d" "$(post_write src/zero.ts "$ELIDED")" "$PH"
d=$(write src/blank.ts "$ELIDED"); put src/blank.ts "$ELIDED"
warns "empty existing file -> warn, no deny: whitespace-only" "$d" "$(post_write src/blank.ts "$ELIDED")" "$PH"

fresh; put src/stats.ts "$BASE"
d=$(export CC_COMMENT_GUARD=off CC_ELISION_GUARD=off; write src/stats.ts "$ELIDED"); put src/stats.ts "$ELIDED"
warns "both guards off, CC_REMIND on -> still warns" "$d" "$(post_write src/stats.ts "$ELIDED")" "$PH"

echo
[ "$rc" -eq 0 ] && echo "elision-guard.test: all cases passed" || echo "elision-guard.test: FAILURES above"
exit "$rc"
