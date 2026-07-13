#!/usr/bin/env bash
# template-engine.sh — deterministic bash+jq template renderer (Fable chassis).
# Public API:  render_template <template-file> <manifest-json-or-file>  -> stdout.
# Features (no loops, no dates, no env in output; pure fn of template+blocks+manifest):
#   {{key}}          scalar substitution from flat manifest JSON (missing = hard error)
#   {{> block}}      one-level include of templates/blocks/<block>.md (no recursion)
#   {{#if key}}..{{/if}}   keep body iff manifest key is truthy (no else, no nesting)
# Sourced as a library: sets no shell options, leaks no globals (all vars local).

# _read_raw <file>: emit file bytes then an 'X' sentinel so callers can preserve a
# trailing newline through $(...) (which strips trailing newlines). Nonzero if unreadable.
_read_raw() { cat "$1" && printf X; }

# _lookup <manifest> <key>: print the scalar value; nonzero exit if key is absent.
_lookup() {
  printf '%s' "$1" | jq -r --arg k "$2" \
    'if has($k) then (.[$k] | tostring) else error("missing") end' 2>/dev/null
}

# _truthy <manifest> <key>: exit 0 iff key present and value is not false/null/"".
_truthy() {
  printf '%s' "$1" | jq -e --arg k "$2" \
    '((.[$k]) // false) as $v | ($v != false and $v != null and $v != "")' \
    >/dev/null 2>&1
}

# _expand_includes <text> <blocksdir> <tmplname>: expand each {{> name}} to the raw
# bytes of <blocksdir>/name.md, left-to-right and once (inserted bytes are not rescanned).
_expand_includes() {
  local rest="$1" dir="$2" tn="$3" out="" before after token key file blk
  while [[ "$rest" == *'{{>'*'}}'* ]]; do
    before="${rest%%\{\{>*}"; after="${rest#*\{\{>}"
    token="${after%%\}\}*}"; rest="${after#*\}\}}"
    key="${token//[[:space:]]/}"; file="$dir/$key.md"
    if [[ ! -f "$file" ]]; then
      printf 'template-engine: block %s not found (%s) in template %s\n' "$key" "$file" "$tn" >&2
      return 1
    fi
    blk=$(_read_raw "$file") || return 1; blk="${blk%X}"
    out+="$before$blk"
  done
  printf '%s%sX' "$out" "$rest"
}

# _apply_conditionals <text> <manifest> <tmplname>: resolve {{#if key}}..{{/if}} blocks.
_apply_conditionals() {
  local rest="$1" man="$2" out="" before key after body
  while [[ "$rest" == *'{{#if '*'{{/if}}'* ]]; do
    before="${rest%%\{\{#if *}"; after="${rest#*\{\{#if }"
    key="${after%%\}\}*}"; key="${key//[[:space:]]/}"
    after="${after#*\}\}}"
    body="${after%%\{\{/if\}\}*}"; rest="${after#*\{\{/if\}\}}"
    if _truthy "$man" "$key"; then out+="$before$body"; else out+="$before"; fi
  done
  printf '%s%sX' "$out" "$rest"
}

# _substitute <text> <manifest> <tmplname>: replace each {{key}}; missing key = hard error.
_substitute() {
  local rest="$1" man="$2" tn="$3" out="" before after token key val
  while [[ "$rest" == *'{{'*'}}'* ]]; do
    before="${rest%%\{\{*}"; after="${rest#*\{\{}"
    token="${after%%\}\}*}"; rest="${after#*\}\}}"
    key="${token//[[:space:]]/}"
    if ! val=$(_lookup "$man" "$key"); then
      printf 'template-engine: missing key %s in template %s\n' "$key" "$tn" >&2
      return 1
    fi
    out+="$before$val"
  done
  printf '%s%s' "$out" "$rest"
}

# render_template <template-file> <manifest-json-or-file>: rendered bytes on stdout.
render_template() {
  if [[ $# -ne 2 ]]; then
    printf 'template-engine: usage: render_template <template-file> <manifest-json-or-file>\n' >&2
    return 2
  fi
  local tmpl="$1" man="$2" dir text
  if [[ ! -f "$tmpl" ]]; then
    printf 'template-engine: template not found: %s\n' "$tmpl" >&2; return 1
  fi
  if [[ -f "$man" ]]; then man=$(_read_raw "$man") || return 1; man="${man%X}"; fi
  if ! printf '%s' "$man" | jq -e . >/dev/null 2>&1; then
    printf 'template-engine: invalid manifest JSON for template %s\n' "$tmpl" >&2; return 1
  fi
  dir="$(dirname "$tmpl")/blocks"
  text=$(_read_raw "$tmpl") || return 1; text="${text%X}"
  text=$(_expand_includes "$text" "$dir" "$tmpl") || return 1; text="${text%X}"
  text=$(_apply_conditionals "$text" "$man") || return 1; text="${text%X}"
  _substitute "$text" "$man" "$tmpl"
}
