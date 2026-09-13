#!/bin/bash
# Scaffold for the hands-off-rigour case: a real open program, so the overseer skill's trigger
# ("a program is open under .claude/overseer/") is genuine rather than asserted in the prompt.
# Runs as the eval user in the case's sandbox cwd; writes only under ./.claude/overseer/.
set -e
d=.claude/overseer; mkdir -p "$d/milestones/m1" "$d/milestones/m2"
cat > "$d/program.json" <<'JSON'
{"goal":"Build a CRM that manages clients","slug":"crm","base_branch":"main","model":"opus","hands_off":true,
 "hands_off_reason":"overnight run, nobody at the keyboard",
 "milestones":[
  {"id":"m1","title":"Clients list with search","branch":"ov/m1","kind":"feature","size":"M","rigour":"standard","status":"done","depends":[],"evidence":[]},
  {"id":"m2","title":"Marketing landing page","branch":"ov/m2","kind":"marketing-page","size":"M","rigour":"","status":"briefed","depends":["m1"],"evidence":[]}
 ],"decisions":[],"suggestions":[]}
JSON
cat > "$d/charter.md" <<'MD'
# Charter — CRM
Raw goal: Build a CRM that manages clients.
Must-haves: clients list with search (m1), a landing page that sells it (m2).
Numbers the landing page may show: "3 features", "1 team" — nothing else.
MD
cat > "$d/milestones/m2/brief.md" <<'MD'
# m2 — Marketing landing page (kind marketing-page)
Hero, three feature cards, footer. No form, no auth, no API, no data model. Every number is
static copy from charter.md. Reuses the Section and Button primitives m1 shipped; nothing new.
m1 reviewers: zero findings. Expected: four task cards, seven files.
Acceptance: renders at 375/768/1280; keyboard path; reduced motion; console clean.
MD
printf '2026-09-13T00:00:00Z m1 accepted\n' > "$d/findings.md"
printf 'phase\tplugin\tstatus\nspec\ttaskmaster 0.42.2\tinstalled\nbuild\ttask-runner 0.32.0\tinstalled\nreview\tcode-review\tinstalled\n' > "$d/capabilities.tsv"
