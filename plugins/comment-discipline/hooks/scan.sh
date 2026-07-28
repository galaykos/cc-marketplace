#!/bin/bash
# Absolute-path shebang not `/usr/bin/env bash`: the fail-open guarantee must hold
# even under a stripped PATH where `env bash` exits 127.
# PostToolUse comment-discipline guard (warn-only). On an Edit/Write/MultiEdit it inspects
# only the *added* text and emits ONE `comment-discipline:` line when it matches a
# high-confidence noise pattern. Silence is the common case.
#
# The warning is emitted as the PostToolUse stdout JSON envelope
# ({"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":...}}, exit 0)
# — the one non-blocking channel the executing model actually receives; plain stdout text
# with exit 0 never reaches it (same channel reasoning as task-runner/hooks/scope.sh).
# `additionalContext` is NOT a blocking key: it adds context, it cannot veto. This hook
# still NEVER blocks or vetoes an edit — it emits no `permissionDecision` and no
# `decision`. Fail-open: a missing jq/awk, or any error, exits 0.
{
  command -v jq  >/dev/null 2>&1 || exit 0
  command -v awk >/dev/null 2>&1 || exit 0

  input=$(cat)
  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  case "$tool" in Edit|Write|MultiEdit) ;; *) exit 0 ;; esac

  fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
  [ -n "$fp" ] || exit 0

  # Generated, vendored, and tooling paths are exempt: their header banners and usage
  # blocks are deliberate, and nobody edits them by hand for readability.
  case "$fp" in
    */.claude/*|*/node_modules/*|*/vendor/*|*/dist/*|*/build/*|*/.git/*) exit 0 ;;
    */scripts/*.sh|*/templates/*|*/plugins/*/hooks/*|*/migrations/*) exit 0 ;;
  esac

  # Code only. Config and prose formats use comments for navigation, which this rule
  # does not govern.
  case "$fp" in
    *.js|*.jsx|*.ts|*.tsx|*.mjs|*.cjs|*.vue|*.svelte) ;;
    *.php|*.py|*.rb|*.go|*.rs|*.java|*.kt|*.kts|*.swift|*.scala|*.dart) ;;
    *.c|*.h|*.cpp|*.hpp|*.cc|*.cs|*.m|*.mm) ;;
    *.sh|*.bash|*.zsh|*.pl|*.lua|*.ex|*.exs|*.jl|*.r|*.groovy) ;;
    *.sql|*.css|*.scss|*.less|*.graphql|*.tf) ;;
    *) exit 0 ;;
  esac

  added=$(printf '%s' "$input" | jq -r '
    [ .tool_input.content    // empty,
      .tool_input.new_string // empty,
      ( .tool_input.edits // [] | map(.new_string // empty) | join("\n") )
    ] | join("\n")' 2>/dev/null) || exit 0
  [ -n "$added" ] || exit 0

  warn=$(printf '%s\n' "$added" | awk '
  function add_tok(set, w,   x) {
    if (w == "") return
    x = tolower(w)
    if (length(x) < 2) return
    set[x] = 1
    if (length(x) > 3 && substr(x, length(x)) == "s") set[substr(x, 1, length(x) - 1)] = 1
  }
  # camelCase and snake_case carry the same words a comment would spell out, so a name
  # only counts as "already says it" once it is split back into those words.
  function split_ident(w, set,   i, c, cur) {
    cur = ""
    for (i = 1; i <= length(w); i++) {
      c = substr(w, i, 1)
      if (c == "_" || c == "$" || c == "-") { add_tok(set, cur); cur = ""; continue }
      if (c ~ /[A-Z]/ && cur != "" && substr(cur, length(cur)) ~ /[a-z0-9]/) {
        add_tok(set, cur); cur = c; continue
      }
      cur = cur c
    }
    add_tok(set, cur)
  }
  function code_tokens(l, set,   n, arr, i, w) {
    n = split(l, arr, /[^A-Za-z0-9_$]+/)
    for (i = 1; i <= n; i++) {
      w = arr[i]
      if (w == "") continue
      add_tok(set, w)
      split_ident(w, set)
    }
  }
  # Operators say in symbols what a restating comment says in words; without this map
  # "// increment the counter" over "counter++" reads as new information.
  function op_tokens(l, set) {
    if (l ~ /\+\+/)   { add_tok(set, "increment"); add_tok(set, "increase"); add_tok(set, "bump"); add_tok(set, "count") }
    if (l ~ /--/)     { add_tok(set, "decrement"); add_tok(set, "decrease"); add_tok(set, "subtract") }
    if (l ~ /\+=/)    { add_tok(set, "add"); add_tok(set, "increment"); add_tok(set, "append"); add_tok(set, "increase") }
    if (l ~ /-=/)     { add_tok(set, "subtract"); add_tok(set, "decrease") }
    if (l ~ /=/)      { add_tok(set, "set"); add_tok(set, "assign"); add_tok(set, "store"); add_tok(set, "save"); add_tok(set, "update"); add_tok(set, "initialize"); add_tok(set, "init"); add_tok(set, "define"); add_tok(set, "declare"); add_tok(set, "value") }
    if (l ~ /(^|[^A-Za-z])return([^A-Za-z]|$)/) { add_tok(set, "return"); add_tok(set, "result"); add_tok(set, "output"); add_tok(set, "give") }
    if (l ~ /(^|[^A-Za-z])if([^A-Za-z]|$)/)     { add_tok(set, "check"); add_tok(set, "handle"); add_tok(set, "test") }
    if (l ~ /(^|[^A-Za-z])(for|while|forEach|foreach|map)([^A-Za-z]|$)/) { add_tok(set, "loop"); add_tok(set, "iterate"); add_tok(set, "over"); add_tok(set, "through"); add_tok(set, "every") }
    if (l ~ /(^|[^A-Za-z])new([^A-Za-z]|$)/)    { add_tok(set, "create"); add_tok(set, "make"); add_tok(set, "instantiate"); add_tok(set, "build"); add_tok(set, "construct") }
    if (l ~ /(^|[^A-Za-z])(throw|raise)([^A-Za-z]|$)/) { add_tok(set, "throw"); add_tok(set, "raise"); add_tok(set, "error"); add_tok(set, "fail") }
    if (l ~ /(^|[^A-Za-z])(delete|remove|unset|splice|drop)([^A-Za-z]|$)/) { add_tok(set, "delete"); add_tok(set, "remove"); add_tok(set, "drop"); add_tok(set, "clear") }
    if (l ~ /(^|[^A-Za-z])(push|append|insert|add)([^A-Za-z]|$)/) { add_tok(set, "add"); add_tok(set, "append"); add_tok(set, "insert") }
    if (l ~ /(^|[^A-Za-z])(import|require|include|use)([^A-Za-z]|$)/) { add_tok(set, "import"); add_tok(set, "load"); add_tok(set, "require"); add_tok(set, "include") }
    if (l ~ /(^|[^A-Za-z])(log|print|echo|puts|printf|println)([^A-Za-z]|$)/) { add_tok(set, "log"); add_tok(set, "print"); add_tok(set, "output"); add_tok(set, "debug"); add_tok(set, "write"); add_tok(set, "show") }
    if (l ~ /(^|[^A-Za-z])(await|async)([^A-Za-z]|$)/) { add_tok(set, "wait"); add_tok(set, "await"); add_tok(set, "async") }
    if (l ~ /(^|[^A-Za-z])(try|catch|except|rescue)([^A-Za-z]|$)/) { add_tok(set, "try"); add_tok(set, "catch"); add_tok(set, "handle"); add_tok(set, "error"); add_tok(set, "guard") }
    if (l ~ /(^|[^A-Za-z])(null|nil|None|undefined)([^A-Za-z]|$)/) { add_tok(set, "clear"); add_tok(set, "reset"); add_tok(set, "empty"); add_tok(set, "blank") }
    if (l ~ /(^|[^A-Za-z])true([^A-Za-z]|$)/)  { add_tok(set, "enable"); add_tok(set, "allow"); add_tok(set, "on") }
    if (l ~ /(^|[^A-Za-z])false([^A-Za-z]|$)/) { add_tok(set, "disable"); add_tok(set, "block"); add_tok(set, "off") }
    if (l ~ /(length|count|size)/)  { add_tok(set, "count"); add_tok(set, "length"); add_tok(set, "size"); add_tok(set, "number"); add_tok(set, "total") }
    if (l ~ /sort/)   { add_tok(set, "sort"); add_tok(set, "order"); add_tok(set, "rank") }
    if (l ~ /filter/) { add_tok(set, "filter"); add_tok(set, "keep"); add_tok(set, "select"); add_tok(set, "exclude") }
    if (l ~ /(function|=>|def )/) { add_tok(set, "define"); add_tok(set, "declare"); add_tok(set, "function"); add_tok(set, "helper") }
    if (l ~ /\+/) { add_tok(set, "add"); add_tok(set, "sum"); add_tok(set, "plus"); add_tok(set, "concat"); add_tok(set, "join"); add_tok(set, "combine") }
    if (l ~ /\*/) { add_tok(set, "multiply"); add_tok(set, "times"); add_tok(set, "product") }
    if (l ~ /\//) { add_tok(set, "divide"); add_tok(set, "ratio") }
    if (l ~ /%/)  { add_tok(set, "modulo"); add_tok(set, "remainder") }
    if (l ~ /[<>]/) { add_tok(set, "compare"); add_tok(set, "greater"); add_tok(set, "less"); add_tok(set, "than"); add_tok(set, "exceeds") }
    if (l ~ /(\?\?|\|\|)/) { add_tok(set, "default"); add_tok(set, "fallback") }
  }
  function cbody(l,   s) {
    s = l
    sub(/^[ \t]+/, "", s)
    if (s ~ /^#!/) return ""
    if (s ~ /^\/\//)  { sub(/^\/\/+[ \t]*/, "", s); return s }
    if (s ~ /^\/\*/)  { sub(/^\/\*+[ \t]*/, "", s); sub(/[ \t]*\*\/[ \t]*$/, "", s); return s }
    if (s ~ /^\*/ && s !~ /^\*[A-Za-z0-9_(]/) { sub(/^\*+[ \t]*/, "", s); sub(/[ \t]*\*\/[ \t]*$/, "", s); return s }
    if (s ~ /^#[ \t]/ || s ~ /^##/) { sub(/^#+[ \t]*/, "", s); return s }
    if (s ~ /^-- /)   { sub(/^--[ \t]*/, "", s); return s }
    return ""
  }
  # Legally required, machine-read, or tool-directive comments are not prose anyone
  # chose to write, so they are outside this rule entirely.
  function exempt(b,   x) {
    x = tolower(b)
    if (x ~ /spdx|copyright|all rights reserved|licensed under|license:|licence:/) return 1
    if (x ~ /eslint-|tslint|jshint|ts-expect-error|ts-ignore|@ts-|type: *ignore|noqa|phpcs:|phpstan-|psalm-|prettier-ignore|biome-ignore|stylelint-|pylint:|rubocop:|nolint|golangci|istanbul ignore|c8 ignore|codecoverageignore|shellcheck|coverage:/) return 1
    return 0
  }
  function is_banner(b,   c) {
    if (b !~ /^[=*#_~-][=*#_~-][=*#_~-]/ && b !~ /[=*#_~-][=*#_~-][=*#_~-][ \t]*$/) return 0
    c = b
    gsub(/[^A-Za-z0-9]/, "", c)
    return (length(c) <= 24)
  }
  function is_code(b) {
    if (b ~ /^[})\];]+[ \t]*;?[ \t]*$/) return 1
    if (b ~ /;[ \t]*$/ && b ~ /[=(]/) return 1
    if (b ~ /^(if|for|while|switch|foreach)[ \t]*\(/) return 1
    if (b ~ /^(return|const|let|var|def|class|function|import|export|public|private|protected|echo|print|new|await|async)[ \t]/ && b ~ /[=({:]/) return 1
    if (b ~ /^[A-Za-z_$][A-Za-z0-9_$.]*\(.*\)[ \t]*;?[ \t]*$/) return 1
    if (b ~ /^[$@]?[A-Za-z_][A-Za-z0-9_]*[ \t]*=[^=]/) return 1
    return 0
  }
  function is_bare_todo(b) {
    if (b !~ /TODO|FIXME|XXX|HACK/) return 0
    if (b ~ /#[0-9]/) return 0
    if (b ~ /[A-Z][A-Z0-9]+-[0-9]/) return 0
    if (b ~ /https?:\/\//) return 0
    return 1
  }
  function is_dead_tag(b,   t, n, arr, i, name, desc, seen, d) {
    if (b ~ /^@returns?[ \t]+void[ \t.]*$/) return 1
    if (b ~ /^@returns?[ \t]*$/) return 1
    if (b ~ /^:param[ \t]/) { t = b; sub(/^:param[ \t]+/, "", t); sub(/:/, " ", t) }
    else if (b ~ /^@param[ \t]/) { t = b; sub(/^@param[ \t]+/, "", t) }
    else return 0
    n = split(t, arr, /[ \t]+/)
    name = ""
    for (i = 1; i <= n && i <= 2; i++) if (arr[i] ~ /^\$/) { name = substr(arr[i], 2); break }
    if (name == "" && n >= 2 && arr[1] ~ /^[A-Za-z_|\\{<]/ && arr[2] ~ /^[A-Za-z_]/) name = arr[2]
    if (name == "" && n == 1) name = arr[1]
    if (name == "") return 0
    seen = 0; desc = ""
    for (i = 1; i <= n; i++) {
      if (!seen && (arr[i] == name || arr[i] == ("$" name))) { seen = 1; continue }
      if (seen) desc = desc " " arr[i]
    }
    if (!seen) return 0
    d = tolower(desc)
    gsub(/[.,:]/, "", d)
    gsub(/^[ \t]+|[ \t]+$/, "", d)
    sub(/^(the|a|an)[ \t]+/, "", d)
    if (d == "") return 1
    gsub(/[ \t]/, "", d)
    return (d == tolower(name))
  }
  # Every content word of the comment must already be recoverable from the code line.
  # Requiring ALL of them, not a ratio, is what keeps this warning credible.
  function restates(b, code,   set, n, arr, i, w, ct, sing) {
    split("", set)
    code_tokens(code, set)
    op_tokens(code, set)
    n = split(b, arr, /[^A-Za-z0-9_]+/)
    ct = 0
    for (i = 1; i <= n; i++) {
      w = tolower(arr[i])
      if (w == "" || length(w) < 2) continue
      if (w in SW) continue
      ct++
      if (w in set) continue
      sing = (length(w) > 3 && substr(w, length(w)) == "s") ? substr(w, 1, length(w) - 1) : ""
      if (sing != "" && (sing in set)) continue
      return 0
    }
    return (ct > 0)
  }
  BEGIN {
    split("the a an to to of for and or is are was were be being been this that these those it its we you i they he she then now here there in on on at by with from as into each all any some if so do does did not no our your their and but when while where which who what how new old up down out off over under again very can will would should could may might must has have had", swl, " ")
    for (i in swl) SW[swl[i]] = 1
    split("restating the next line|section banner|commented-out code|bare TODO|docblock tag repeating the signature", CATS, "|")
  }
  { L[++T] = $0 }
  END {
    for (i = 1; i <= T; i++) {
      b = cbody(L[i])
      if (b == "" || exempt(b)) continue
      if (is_banner(b))       { H[2]++; total++; continue }
      if (is_code(b))         { H[3]++; total++; continue }
      if (is_bare_todo(b))    { H[4]++; total++; continue }
      if (is_dead_tag(b))     { H[5]++; total++; continue }
      j = i + 1
      while (j <= T && (L[j] ~ /^[ \t]*$/ || cbody(L[j]) != "")) j++
      if (j <= T && restates(b, L[j])) { H[1]++; total++ }
    }
    if (total == 0) exit 0
    parts = ""
    for (k = 1; k <= 5; k++) {
      if (!(k in H)) continue
      parts = parts (parts == "" ? "" : ", ") H[k] " " CATS[k]
    }
    printf "comment-discipline: %d added %s (%s) — check the routing table in the comment-discipline skill for where those facts belong.\n", total, (total == 1 ? "comment looks like noise" : "comments look like noise"), parts
  }')
  [ -n "$warn" ] || exit 0

  # jq builds the envelope so the message stays valid JSON whatever the comment text
  # contains. jq presence is guaranteed by the guard at the top of the block.
  jq -cn --arg ctx "$warn" \
    '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$ctx}}'
} 2>/dev/null
exit 0
