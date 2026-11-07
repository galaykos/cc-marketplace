#!/usr/bin/env bash
# sources-check.sh --transcript <agent.jsonl> [return-file] (stdin when none) — every URL a researcher `url:` line or verifier `FETCH:` line cites must appear in that agent's own WebFetch calls or their results (a redirect target counts). Exit 0 all fetched, 1 one `sources-check: not fetched this session: <url>` line per miss, 2 usage or no cited URL.
# Misses: whether the fetched page says what the quote claims, URLs cited in prose outside those lines, a fetch made by another agent, and a page fetched through a tool other than WebFetch.
# Why, limits, history: rationale/derivations/plugin-ultra-deep-research.md § plugins/ultra-deep-research/scripts/sources-check.sh
set -u

usage() { printf 'sources-check: %s\n' "$1" >&2; exit 2; }
tr_file=""
while [ $# -gt 0 ]; do
  case "$1" in
    --transcript) [ $# -ge 2 ] || usage "--transcript needs a path"; tr_file=$2; shift 2 ;;
    -h | --help) usage "usage: sources-check.sh --transcript <agent.jsonl> [return-file]" ;;
    *) break ;;
  esac
done
[ -n "$tr_file" ] && [ -r "$tr_file" ] || usage "no readable --transcript"
command -v jq >/dev/null 2>&1 || usage "jq is required"
ret=$(cat "${1:-/dev/stdin}") || usage "cannot read the return"

norm() { sed -E 's/[)>.,;"'"'"'`]+$//; s/#.*$//; s|^http://|https://|; s|/+$||'; }

cited=$(printf '%s\n' "$ret" | grep -E '^[[:space:]]*(url:|FETCH:)' \
  | grep -oE 'https?://[^[:space:]<>"`]+' | norm | sort -u)
[ -n "$cited" ] || usage "no cited URL on a url: or FETCH: line"

# URLs in WebFetch inputs, plus any URL in the results of those calls (redirect targets are reported there).
fetched=$(jq -r '
  if .type == "assistant" then (.message.content // [])[] | select(.type == "tool_use" and .name == "WebFetch") | "ID " + .id, (.input.url // empty)
  elif .type == "user" and ((.message.content | type) == "array") then
    (.message.content[] | select(.type == "tool_result") | "RES " + .tool_use_id + " " + ((.content | if type == "array" then map(.text? // "") | join(" ") else tostring end) | gsub("\n"; " ")))
  else empty end' "$tr_file" 2>/dev/null | awk '
    /^ID / { ids[$2] = 1; next }
    /^RES / { if ($2 in ids) { $1 = ""; $2 = ""; print } ; next }
    { print }' | grep -oE 'https?://[^[:space:]<>"`]+' | norm | sort -u)

miss=0
while IFS= read -r u; do
  [ -n "$u" ] || continue
  printf '%s\n' "$fetched" | grep -qxF "$u" && continue
  printf 'sources-check: not fetched this session: %s\n' "$u"
  miss=1
done <<EOF
$cited
EOF
exit "$miss"
