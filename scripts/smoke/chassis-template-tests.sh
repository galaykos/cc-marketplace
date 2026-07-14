#!/usr/bin/env bash
# Renders the five chassis templates (templates/*.tmpl) with the hand-built sample
# manifests (templates/samples/*.json) through card 01's template engine and asserts
# the Fable payload contract: frontmatter fence at line 1, generated header after it,
# payload markers present (triage / CONFIRMED / Checked: / Apply all), lang/concern
# variants gate correctly, worker-agent carries all six frontmatter fields plus the
# three-strikes kill-trigger, reminder-hook has shebang line 1 + guards + optional
# extraGuard, and no {{token}} survives. Engine path overridable via TEMPLATE_ENGINE
# (default scripts/lib/template-engine.sh) so this runs before card 01 lands in-tree.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENGINE="${TEMPLATE_ENGINE:-$REPO_ROOT/scripts/lib/template-engine.sh}"
TPL="$REPO_ROOT/templates"
SAMPLES="$TPL/samples"

if [[ ! -f "$ENGINE" ]]; then
  printf 'chassis-template-tests: engine not found: %s\n' "$ENGINE" >&2
  printf '  set TEMPLATE_ENGINE=/path/to/scripts/lib/template-engine.sh (card 01 output)\n' >&2
  exit 1
fi
# shellcheck source=/dev/null
source "$ENGINE"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
rc=0
pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n    %s\n' "$1" "${2:-}"; rc=1; }

render() { # template sample -> file ; hard-fail on render error
  local t="$1" s="$2" out="$3"
  if ! render_template "$t" "$s" > "$out" 2>"$out.err"; then
    fail "render $t with $s" "$(cat "$out.err")"; return 1
  fi
  return 0
}
line1() { IFS= read -r _l < "$1"; printf '%s' "$_l"; }
line_n() { awk -v n="$2" 'NR==n{print; exit}' "$1"; }
grepc() { grep -c -- "$2" "$1" 2>/dev/null || true; }
has()  { grep -q -F -- "$2" "$1"; }

expect_count() { # file marker expected desc
  local n; n="$(grepc "$1" "$2")"
  if [[ "$n" == "$3" ]]; then pass "$4 ($2 == $3)"; else fail "$4" "grep -c '$2' = $n, expected $3"; fi
}
expect_has()    { if has "$1" "$2"; then pass "$3"; else fail "$3" "missing: $2"; fi; }
expect_absent() { if has "$1" "$2"; then fail "$3" "present but should be absent: $2"; else pass "$3"; fi; }

# ---- review command: lang variant ---------------------------------------------
L="$WORK/review-lang.md"
if render "$TPL/review-command.md.tmpl" "$SAMPLES/stack-review-lang.json" "$L"; then
  [[ "$(line1 "$L")" == "---" ]] && pass "lang: line 1 is ---" || fail "lang: line 1 is ---" "got [$(line1 "$L")]"
  expect_has "$L" "<!-- generated from templates/review-command.md.tmpl" "lang: generated header after fence"
  expect_count "$L" "triage" 1 "lang: triage marker"
  expect_count "$L" "CONFIRMED" 2 "lang: CONFIRMED marker (format tag + evidence rule)"
  expect_count "$L" "Checked:" 1 "lang: Checked: marker"
  expect_count "$L" "Apply all" 1 "lang: Apply all marker"
  expect_has "$L" "Apply critical+high only" "lang: apply critical+high option"
  expect_has "$L" "https://laravel.com/docs" "lang: docsUrl rendered (lang block kept)"
  expect_has "$L" "backend-engineer → task-runner:task-executor if installed → inline" "lang: workerChain stamped"
  expect_absent "$L" "design-doc review" "lang: concern affordance dropped"
fi

# ---- review command: concern variant ------------------------------------------
C="$WORK/review-concern.md"
if render "$TPL/review-command.md.tmpl" "$SAMPLES/stack-review-concern.json" "$C"; then
  [[ "$(line1 "$C")" == "---" ]] && pass "concern: line 1 is ---" || fail "concern: line 1 is ---" "got [$(line1 "$C")]"
  expect_count "$C" "triage" 1 "concern: triage marker"
  expect_count "$C" "CONFIRMED" 2 "concern: CONFIRMED marker (format tag + evidence rule)"
  expect_count "$C" "Checked:" 1 "concern: Checked: marker"
  expect_count "$C" "Apply all" 1 "concern: Apply all marker"
  expect_has "$C" "section/heading for a design-doc review" "concern: design-doc locator affordance kept"
  expect_has "$C" "observability-engineer → task-runner:task-executor if installed → inline" "concern: workerChain stamped"
  expect_absent "$C" "https://laravel.com/docs" "concern: lang block dropped"
fi

# ---- worker agent -------------------------------------------------------------
W="$WORK/worker.md"
if render "$TPL/worker-agent.md.tmpl" "$SAMPLES/worker-agent.json" "$W"; then
  [[ "$(line1 "$W")" == "---" ]] && pass "worker: line 1 is ---" || fail "worker: line 1 is ---" "got [$(line1 "$W")]"
  for k in "name:" "description:" "tools:" "model:" "effort:" "bestpractices-skill:"; do
    expect_has "$W" "$k" "worker: frontmatter has $k"
  done
  expect_has "$W" "PROACTIVELY" "worker: description carries PROACTIVELY (validate.sh gate)"
  expect_has "$W" "three strikes" "worker: three-strikes kill-trigger present"
  expect_has "$W" "fails its verify three" "worker: kill-trigger cites 3 failed cycles"
  expect_absent "$W" "Domain checklist" "worker: no restated checklist (skill pointer only)"
fi

# ---- suite uninstall ----------------------------------------------------------
U="$WORK/uninstall.md"
if render "$TPL/suite-uninstall.md.tmpl" "$SAMPLES/suite-uninstall.json" "$U"; then
  [[ "$(line1 "$U")" == "---" ]] && pass "uninstall: line 1 is ---" || fail "uninstall: line 1 is ---" "got [$(line1 "$U")]"
  expect_has "$U" "<!-- generated from templates/suite-uninstall.md.tmpl" "uninstall: generated header after fence"
  expect_has "$U" "claude plugin uninstall quality-suite --prune -y" "uninstall: bundle param rendered"
  expect_absent "$U" "list --json" "uninstall: taskmaster divergence gone"
fi

# ---- reminder hook: plain -----------------------------------------------------
H="$WORK/remind.sh"
if render "$TPL/reminder-hook.sh.tmpl" "$SAMPLES/reminder-hook.json" "$H"; then
  [[ "$(line1 "$H")" == "#!/usr/bin/env bash" ]] && pass "hook: line 1 is shebang" || fail "hook: line 1 is shebang" "got [$(line1 "$H")]"
  case "$(line_n "$H" 2)" in "# generated"*) pass "hook: line 2 is # generated header" ;; *) fail "hook: line 2 is # generated header" "got [$(line_n "$H" 2)]" ;; esac
  expect_has "$H" "command -v jq" "hook: jq fail-open guard"
  expect_has "$H" 'case "$prompt" in "" | "/"*) exit 0' "hook: empty + slash guards"
  expect_has "$H" "adspower|local" "hook: regex substituted"
  expect_absent "$H" " && [ " "hook(plain): no extraGuard when null"
fi

# ---- reminder hook: extraGuard ------------------------------------------------
HE="$WORK/remind-eg.sh"
if render "$TPL/reminder-hook.sh.tmpl" "$SAMPLES/reminder-hook-extraguard.json" "$HE"; then
  expect_has "$HE" '&& [ "${#prompt}" -lt 200 ]' "hook(extraGuard): thin-prompt condition rendered"
  expect_has "$HE" "build|create|add" "hook(extraGuard): regex substituted"
fi

# ---- navigator check ---------------------------------------------------------
N="$WORK/navigator-check.md"
if render "$TPL/navigator-check.md.tmpl" "$SAMPLES/navigator.json" "$N"; then
  [[ "$(line1 "$N")" == "---" ]] && pass "navigator: line 1 is ---" || fail "navigator: line 1 is ---" "got [$(line1 "$N")]"
  expect_has "$N" "<!-- generated from templates/navigator-check.md.tmpl" "navigator: generated header after fence"
  expect_has "$N" "Invoke the \`sample-docs\` skill from this plugin for \$ARGUMENTS" "navigator: skill + goalDescriptor stamped mid-sentence"
  expect_has "$N" "must come from pages fetched now, not memory" "navigator: goalDescriptor staleness rationale carried"
  expect_has "$N" "1. Fetch https://example.com/docs" "navigator: reportBody step 1 verbatim"
  expect_has "$N" "3. Report, in order:" "navigator: reportBody step 3 verbatim"
  expect_has "$N" "If any needed page is unreachable" "navigator: docs-unreachable block inlined"
  expect_has "$N" "do not substitute memory for the missing page" "navigator: docs-unreachable full wording"
  expect_has "$N" "When endpoints, flow, and the sample handoff are all resolved" "navigator: proceedGate scalar substituted inside block"
  expect_has "$N" "Proceed with the task using these doc-backed sample endpoints and options now" "navigator: canonical verb + closerObject scalar substituted inside block"
  expect_has "$N" "Headless: report only." "navigator: headless clause present"
  expect_absent "$N" "{{proceedGate}}" "navigator: proceedGate token consumed (block var substituted after inlining)"
  expect_absent "$N" "{{closerObject}}" "navigator: closerObject token consumed (block var substituted after inlining)"
fi

# ---- global invariant: no unrendered {{token}} in any output ------------------
for f in "$L" "$C" "$W" "$U" "$H" "$HE" "$N"; do
  [[ -f "$f" ]] || continue
  if grep -q '{{' "$f"; then fail "no unrendered token in $(basename "$f")" "$(grep -n '{{' "$f")"; else pass "no unrendered token in $(basename "$f")"; fi
done

# ---- determinism: second render byte-identical --------------------------------
render_template "$TPL/review-command.md.tmpl" "$SAMPLES/stack-review-lang.json" > "$WORK/d2.md" 2>/dev/null
if diff "$L" "$WORK/d2.md" >/dev/null; then pass "determinism (double render byte-identical)"; else fail "determinism" "$(diff -u "$L" "$WORK/d2.md")"; fi

if [[ $rc -eq 0 ]]; then printf '\nAll chassis-template asserts passed.\n'; else printf '\nSome asserts FAILED.\n'; fi
exit $rc
