#!/bin/bash
# Scaffold for the milestone-verify case: an open interactive program whose m3 is a content-heavy game
# milestone (many cards, a new system, no surface), modelled on the rogue-chess run in
# rationale/session-retro-2026-11-05.md § 1. Writes only under ./.cc-artifacts/overseer/.
set -e
d=.cc-artifacts/overseer; mkdir -p "$d/milestones/m3"
cat > "$d/program.json" <<'JSON'
{"goal":"Finish the roguelike chess game","slug":"chess","base_branch":"master","model":"opus","hands_off":false,
 "milestones":[
  {"id":"m1","title":"Upgrade catalogue 16 to 30","branch":"ov/m1","kind":"game","size":"M","rigour":"lean","status":"done","depends":[],"evidence":[]},
  {"id":"m2","title":"Consumables","branch":"ov/m2","kind":"game","size":"M","rigour":"lean","status":"done","depends":["m1"],"evidence":[]},
  {"id":"m3","title":"Relics","branch":"ov/m3","kind":"game","size":"L","rigour":"","status":"briefed","depends":["m2"],"evidence":[]}
 ],"decisions":[],"suggestions":[]}
JSON
cat > "$d/charter.md" <<'MD'
# Charter — roguelike chess
Raw goal: finish the game with what we can. Unity client, .NET core library with xUnit tests.
MD
cat > "$d/milestones/m3/brief.md" <<'MD'
# m3 — Relics (kind game, size L)
Twelve passive relics, a new RelicSystem no sibling implements, a relic shelf in the HUD.
Acceptance: each relic's effect shows in a run; shelf readable at 375/768/1280; keyboard path.
No auth, no save-format change, no money, no parser. Uses existing HUD primitives only.
m2's range review: two minors, no major. Expected: ten task cards, about twenty files.
Verify: dotnet test core/RogueChess.Core.Tests
MD
printf '2026-11-05T03:12:00Z m2 accepted\n' > "$d/findings.md"
printf 'phase\tinstalled\tmissing\tfallback\nspec\ttaskmaster\t-\t-\nbuild\ttask-runner\t-\t-\nreview\tcode-review\t-\t-\n' > "$d/capabilities.tsv"
