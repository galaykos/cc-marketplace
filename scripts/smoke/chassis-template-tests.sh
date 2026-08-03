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
  # Skill priming: a worker has no `Skill` tool, so the dispatch must resolve and inject
  # the rubric's Read path. Without these the agent's `bestpractices-skill:` names a file
  # it can never open and it works from recalled convention instead.
  expect_has "$L" "bestpractices-skill:" "lang: apply lane names the frontmatter key to resolve"
  expect_has "$L" "skills/<tok>/SKILL.md" "lang: apply lane carries the resolution glob"
  expect_has "$L" "Read <abs-path> before writing" "lang: apply lane carries the injected Read line"
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
  # The worker must name its own lack of a Skill tool and report an unprimed dispatch —
  # otherwise "rubric not loaded" is indistinguishable from "rubric applied".
  expect_has "$W" "no \`Skill\` tool" "worker: states it cannot load the skill itself"
  # Status is FOUR INDEPENDENT FACTS, not a first-match ladder. Five review rounds of
  # mutually-exclusive bullets produced a false alarm or an unreachable state every time;
  # independent fields cannot have that class of bug.
  expect_has "$W" "loaded <k> of <m>" "worker: status line is assembled, not selected"
  expect_has "$W" "This is not" "worker: status is explicitly not a menu to pick from"
  expect_has "$W" "; rescued <names>" "worker: rescued is its own field"
  expect_has "$W" "; missing <names>" "worker: missing is its own field"
  expect_has "$W" "ignored off-name injection" "worker: off-name is its own field"
  # Rescue must be keyed on what LOADED, not on what was NAMED: an injected path that
  # 404s is not a rescue trigger under a name-keyed rule, so a dead injection reported
  # as a perfect dispatch.
  expect_has "$W" "no injected path for them LOADED" "worker: an unreadable injection triggers rescue"
  expect_has "$W" "read successfully" "worker: loaded requires a successful read"
  # A rescue that ends complete still means the caller shipped a broken dispatch.
  expect_has "$W" "REQUIRED even when you end up holding everything" "worker: successful rescue is still reported"
  # <m>=0 must not fire an alarm, or a correct dispatch reports itself failed.
  expect_has "$W" "Emit no line at all in exactly two cases" "worker: zero applicable skills raises no alarm"
  # Both no-line cases must be gated on off-name being empty. Left unqualified, the
  # suppression rule contradicts the emit rule and a routing bug is dropped precisely
  # when the rest of the dispatch was perfect.
  expect_has "$W" "both require there to be NO off-name path" "worker: suppression is gated on off-name"
  expect_has "$W" "ALWAYS produces a line" "worker: an off-name injection is never suppressed"
  # Off-name keys on the NAMED list; keyed on <m> it accuses every stack-narrowed caller.
  expect_has "$W" "this against your NAMED list, never against" "worker: off-name keys on named list, not applying subset"
  expect_has "$W" "do not treat it as authoritative" "worker: an off-name rubric is never applied"
  # Self-rescue backstop: covers direct Agent spawns and any dispatch site that skipped
  # its step — neither of which the orchestrator can reach.
  expect_has "$W" "~/.claude/plugins/marketplaces" "worker: self-rescue prefers the live checkout"
  # Anchored to a path SEGMENT, so a plugin merely named *.backup* is not filtered out.
  expect_has "$W" "grep -v '/[^/]*\\.bak/'" "worker: self-rescue excludes stale .bak mirrors"
  # Other runtimes' mirrors live in dot-dirs under a marketplace root and sort AHEAD of
  # the real plugins/<name>/ copy.
  # The trailing \. is what makes the filter dot-SPECIFIC. Without it the expression
  # discards every marketplace hit and kills rung 3 outright, so assert the full form.
  expect_has "$W" "/marketplaces/[^/]*/\\." "worker: other runtimes' dot-dir mirrors are excluded"
  expect_has "$W" '| sort)' "worker: live-checkout pick is deterministic, not filesystem order"
  # Cache fallback must sort the VERSION SEGMENT: sort -V over whole paths lets the
  # marketplace name dominate and returns 0.9.0 over 0.10.0 across two roots.
  expect_has "$W" 'for(i=NF;i>0;i--)' "worker: cache fallback scans for the version field"
  expect_has "$W" "sort -V | cut -f2-" "worker: cache fallback sorts by version, not whole path"
  # Nested-category skills (skills/<category>/<name>/SKILL.md) ship in installed plugins.
  expect_has "$W" '-o -path "*/skills/*/$s/SKILL.md"' "worker: nested-category skills are matched"
  # The suppressed-mirror count must survive the cache fallback, which reassigns hits/live.
  expect_has "$W" "sup + " "worker: stale-suppressed accumulates across both channels"
  # Copy-runnable: an unsubstituted <name> inside a runnable-looking command gets executed
  # verbatim, returns nothing, and the agent reports an installed skill as unresolved.
  expect_absent "$W" "skills/<name>/SKILL.md" "worker: no unsubstituted placeholder in the self-rescue command"
  expect_has "$W" "for s in \$(echo 'observability-design' | tr ',' ' ')" "worker: self-rescue loop carries the real skill names"
  expect_has "$W" "not the whole menu" "worker: menu rubrics do not false-alarm as partial"
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
  expect_has "$H" 'CC_REMIND:-on' "hook: CC_REMIND off switch present"
  expect_has "$H" 'cut -c1-400' "hook: head-window narrowing present"
  expect_has "$H" 'task-notification|SYSTEM NOTIFICATION' "hook: machinery guard present"
  expect_has "$H" 'grep -qF' "hook: own-command echo guard present"
  expect_has "$H" 'cc-remind-' "hook: per-prompt budget marker present"
fi

# ---- reminder hook: extraGuard ------------------------------------------------
HE="$WORK/remind-eg.sh"
if render "$TPL/reminder-hook.sh.tmpl" "$SAMPLES/reminder-hook-extraguard.json" "$HE"; then
  expect_has "$HE" '&& [ "${#prompt}" -lt 200 ]' "hook(extraGuard): thin-prompt condition rendered"
  expect_has "$HE" "build|create|add" "hook(extraGuard): regex substituted"
fi

# ---- global invariant: no unrendered {{token}} in any output ------------------
for f in "$L" "$C" "$W" "$U" "$H" "$HE"; do
  [[ -f "$f" ]] || continue
  if grep -q '{{' "$f"; then fail "no unrendered token in $(basename "$f")" "$(grep -n '{{' "$f")"; else pass "no unrendered token in $(basename "$f")"; fi
done

# ---- determinism: second render byte-identical --------------------------------
render_template "$TPL/review-command.md.tmpl" "$SAMPLES/stack-review-lang.json" > "$WORK/d2.md" 2>/dev/null
if diff "$L" "$WORK/d2.md" >/dev/null; then pass "determinism (double render byte-identical)"; else fail "determinism" "$(diff -u "$L" "$WORK/d2.md")"; fi

if [[ $rc -eq 0 ]]; then printf '\nAll chassis-template asserts passed.\n'; else printf '\nSome asserts FAILED.\n'; fi
exit $rc
