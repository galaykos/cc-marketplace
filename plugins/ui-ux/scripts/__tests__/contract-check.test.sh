#!/usr/bin/env bash
# Tests for hooks/contract-check.sh: lines an edit ADDS that hand-build a surface, use a raw palette class
# or an arbitrary value fire when the project declares a design contract; old lines, primitives, the shell
# owner's surfaces, tests, CSS, out-of-scope files and a project with no contract stay silent.
set -u
here=$(cd "$(dirname "$0")" && pwd)
HOOK="$here/../../hooks/contract-check.sh"
[ -x "$HOOK" ] || { printf 'FAIL: hook not executable\n'; exit 1; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { printf 'PASS: %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$((fail+1)); }

R="$T/app"; mkdir -p "$R/src/pages" "$R/src/components/ui" "$R/src/layouts" "$R/src/__tests__" "$R/other" "$R/.cc-artifacts/design-kit/design-system"
git -C "$R" init -q; git -C "$R" config user.email t@t; git -C "$R" config user.name t
cat > "$R/.cc-artifacts/design-kit/design-system/contract.json" <<'EOF'
{"surface":{"component":"Card","import":"@/components/ui/card"},"primitives":["src/components/ui/"],"shell":{"owner":["src/layouts/"]},"scope":["src/"]}
EOF
printf 'export function Old() { return <div className="bg-gray-100">old</div> }\n' > "$R/src/pages/tracked.tsx"
git -C "$R" add -A >/dev/null; git -C "$R" commit -qm init

# The payload the host sends a PostToolUse hook for Edit and Write (transcript_path and session_id both present).
edit() { # file old new
  jq -cn --arg f "$1" --arg o "$2" --arg n "$3" --arg c "$R" \
    '{hook_event_name:"PostToolUse",tool_name:"Edit",tool_input:{file_path:$f,old_string:$o,new_string:$n},cwd:$c,session_id:"s1",transcript_path:"/tmp/t1.jsonl"}'
}
write() { # file
  jq -cn --arg f "$1" --arg c "$R" \
    '{hook_event_name:"PostToolUse",tool_name:"Write",tool_input:{file_path:$f,content:""},cwd:$c,session_id:"s1",transcript_path:"/tmp/t1.jsonl"}'
}
run() { printf '%s' "$1" | env -u CC_REMIND -u CC_DESIGN_CONTRACT "$HOOK" 2>/dev/null | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null; }
fires()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (want <$3>, got <$2>)" ;; esac; }
silent() { [ -z "$2" ] && ok "$1" || bad "$1 (want silence, got <$2>)"; }

f="$R/src/pages/a.tsx"; printf '<div className="rounded-lg border p-4">x</div>\n' > "$f"
fires "a hand-built surface names the contract's component" "$(run "$(edit "$f" 'x' '<div className="rounded-lg border p-4">x</div>')")" 'use <Card> from @/components/ui/card'
fires "a raw palette class fires" "$(run "$(edit "$f" 'x' '<p className="text-gray-500">x</p>')")" 'a raw palette class'
fires "an arbitrary px value fires" "$(run "$(edit "$f" 'x' '<p className="text-[13px]">x</p>')")" 'an arbitrary value'
fires "an arbitrary hex fires" "$(run "$(edit "$f" 'x' '<p className="bg-[#1e293b]">x</p>')")" 'an arbitrary value'

f="$R/src/pages/new.tsx"; printf 'export const N = () => <section className="border rounded-xl">n</section>\n' > "$f"
fires "a Write of an untracked file checks every line" "$(run "$(write "$f")")" 'a hand-built surface'

printf 'export function Old() { return <div className="bg-gray-100">old</div> }\nexport const New = () => <b className="text-red-600">n</b>\n' > "$R/src/pages/tracked.tsx"
out=$(run "$(write "$R/src/pages/tracked.tsx")")
case "$out" in *text-red-600*) case "$out" in *bg-gray-100*) bad "a Write of a tracked file names only added lines (old line named: <$out>)" ;; *) ok "a Write of a tracked file names only added lines" ;; esac ;;
  *) bad "a Write of a tracked file names only added lines (got <$out>)" ;; esac

f="$R/src/pages/a.tsx"
silent "a line the old_string already held stays silent" "$(run "$(edit "$f" '<div className="rounded-lg border p-4">x</div>' $'<div className="rounded-lg border p-4">x</div>\n<span>y</span>')")"
silent "rounded without border is no surface" "$(run "$(edit "$f" 'x' '<div className="rounded-lg p-4">x</div>')")"
silent "a border-b divider is no surface" "$(run "$(edit "$f" 'x' '<div className="border-b pb-2">x</div>')")"
silent "semantic tokens stay silent" "$(run "$(edit "$f" 'x' '<p className="bg-primary text-muted-foreground border-border">x</p>')")"
silent "a scale value is no arbitrary value" "$(run "$(edit "$f" 'x' '<p className="text-sm p-4 gap-2">x</p>')")"

f="$R/src/components/ui/card.tsx"; printf 'x\n' > "$f"
silent "the contract's primitives may build surfaces" "$(run "$(edit "$f" 'x' '<div className="rounded-xl border bg-gray-50">x</div>')")"
f="$R/src/layouts/app.tsx"; printf 'x\n' > "$f"
silent "the shell owner may draw its own frame" "$(run "$(edit "$f" 'x' '<aside className="rounded-lg border">x</aside>')")"
fires "the shell owner still gets the palette check" "$(run "$(edit "$f" 'x' '<aside className="bg-zinc-900">x</aside>')")" 'a raw palette class'
f="$R/src/__tests__/a.test.tsx"; printf 'x\n' > "$f"
silent "test files stay silent" "$(run "$(edit "$f" 'x' '<div className="rounded border bg-gray-100">x</div>')")"
f="$R/src/pages/a.css"; printf 'x\n' > "$f"
silent "CSS files stay silent" "$(run "$(edit "$f" 'x' '.a { @apply bg-gray-100; }')")"
f="$R/other/b.tsx"; printf 'x\n' > "$f"
silent "a file outside the contract's scope stays silent" "$(run "$(edit "$f" 'x' '<div className="rounded border">x</div>')")"

f="$R/src/pages/a.tsx"
out=$(edit "$f" 'x' '<p className="text-gray-500">x</p>' | CC_DESIGN_CONTRACT=off "$HOOK" 2>/dev/null)
silent "CC_DESIGN_CONTRACT=off turns it off" "$out"
mv "$R/.cc-artifacts/design-kit/design-system/contract.json" "$T/contract.json"
silent "a project with no contract stays silent" "$(run "$(edit "$f" 'x' '<div className="rounded-lg border bg-gray-100">x</div>')")"
mv "$T/contract.json" "$R/.cc-artifacts/design-kit/design-system/contract.json"

many=$(for i in 1 2 3 4 5 6 7; do printf '<p className="text-gray-%s00">%s</p>\n' "$i" "$i"; done)
fires "more than five hits collapse into a count" "$(run "$(edit "$f" 'x' "$many")")" '+2 more'

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
