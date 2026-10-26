# Four roles — the main session builds, fresh subagents do the rest

The builder never judges its own work. Dispatch each role with the Agent tool as a general-purpose
subagent at the effort named; a subagent has no Skill tool, so paste the contract below into its
prompt. Its isolation is instructed, not enforced — nothing stops a reviewer opening another
file — so the instruction is stated plainly and the return is checked for it. Standing:
agent-graded.

## 1. Breakdown — effort medium, only with a reference video

Prompt: "Reference video: `<path>`. Run
`python3 "<plugin>/scripts/film.py" cuts <path>` for its cuts and shot lengths, then
`film.py sheet <path> --out <ws>/.frames/ref --every 0.1` and Read the sheets covering each cut
(the sheet index gives each sheet's time span).
Return: shot lengths (median and range), shot types, transitions, how type enters and leaves,
pacing per section, and what happens on the beat. Learn the patterns; copy no footage or music."

## 2. Storyboard — effort medium

Prompt: "Brief: `<brief.txt>`. Facts: `<facts.json>`. Beat grid: `<timing.json music>`.
Return three directions that differ in structure, not palette. For each, one table: time, picture,
what the viewer should learn, sound, how it hands off to the next shot. Hard cuts land on beats. A
muted viewer must follow it. Use only lines `facts.json` supports; mark each with its fact id."

The main session shows the three ⏸ (or picks the strongest under run-to-end and logs why).

## 3. Build — the main session, effort high

Once `timing.json` exists: write `style.json` first, render three still frames from it to lock the
style ⏸, then one component per scene. Read every time from `timing.json`, compute every value
from the frame number, seed every random.

## 4. Review — effort high, a NEW subagent every round

Prompt: "You review one rendered film. Read ONLY these: `<mp4>`, `<facts.json>`[, the reference
contact sheets]. Open no other file. Run
`python3 "<plugin>/scripts/film.py" sheet <mp4> --out <ws>/.frames/review-<n> --every 0.2 --per 20`
and Read every sheet. Every on-screen line must come from facts.json. List problems by severity
(blocker / should-fix / polish) with timecodes from the sheet index. Earlier rounds found:
`<list>` — recheck each and say fixed or not. End with exactly `ship` or `another pass`."

The main session fixes the worst first; the next round goes to another new reviewer. Five rounds at
most; still failing → stop and list what is left.

## Muted test — before delivery

A new subagent gets ONLY `film.py sheet <mp4> --every 0.5 --out …` (2 fps) and retells the story.
Compare its retelling with the storyboard's "what the viewer should learn" column; a beat it
missed is a picture problem, not a copy one.
