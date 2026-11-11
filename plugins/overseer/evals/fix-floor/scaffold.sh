#!/bin/bash
# Scaffold for the fix-floor case: m1 in `accepting`, the walk finished, five findings of which one
# fails an acceptance line and four sit below the bar. Writes only under ./.claude/overseer/.
set -e
d=.claude/overseer; mkdir -p "$d/milestones/m1/dispatch" "$d/milestones/m1/evidence"
cat > "$d/program.json" <<'JSON'
{"goal":"Build a CRM that manages clients","slug":"crm","base_branch":"main","model":"opus","hands_off":false,
 "milestones":[
  {"id":"m1","title":"Clients list with search","branch":"ov/m1","kind":"crud","size":"M","rigour":"lean","status":"accepting","depends":[],"evidence":[]},
  {"id":"m2","title":"Client detail page","branch":"ov/m2","kind":"crud","size":"M","rigour":"","status":"queued","depends":["m1"],"evidence":[]}
 ]}
JSON
printf '# Charter — CRM\nMust-haves: clients list with search (m1): empty state, loading skeleton, search with no-results state.\n' > "$d/charter.md"
cat > "$d/milestones/m1/brief.md" <<'MD'
# m1 — Clients list with search
## Acceptance (each line is something a browser can show)
- [ ] Open /clients → the list shows name, company and email per client
- [ ] Type a query that matches nothing → a "No clients match" state with a clear-search action
- [ ] Works at 375, 768 and 1280 px wide; no horizontal scroll
- [ ] Console clean; suite green (`php artisan test`)
## Scope
Touch: resources/js/pages/clients/, app/Http/Controllers/ClientController.php. Do not touch: settings pages, layout.
## Verify
php artisan test
Verify: range
MD
cat > "$d/milestones/m1/findings.md" <<'MD'
# m1 findings — browser walk and ui-ux reviewer, all on HEAD of ov/m1

1. Walk, 1280 px: searching "zzzz" renders a blank page, no message and no way to clear the search. Reproduced twice.
2. Reviewer — low — resources/js/pages/clients/index.tsx:41 — `data2` is a poor variable name.
3. Reviewer — medium — resources/js/pages/clients/index.tsx:60-88 — the row markup could be extracted into a `ClientRow` helper.
4. Console: "NavUser must be used within SidebarProvider" warning on /clients. The same warning shows on `main` on every page.
5. Walk, 375 px: the Save button on /settings/profile is 40 px tall (target 44 px). m1 did not change that page.
MD
