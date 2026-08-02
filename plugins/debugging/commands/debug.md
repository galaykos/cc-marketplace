---
description: Debug an error or symptom systematically — root cause with evidence before any fix
argument-hint: [error-message-stack-trace-or-symptom]
---

Debug the problem described in $ARGUMENTS — an error message, stack trace, or
symptom description (if empty, take the most recent failure in the conversation
or the current test/build output). Invoke the systematic-debugging skill from
this plugin first and follow its phase order exactly: reproduce
deterministically before anything else, read the actual error verbatim (the
first in a cascade, not the last), check what changed (git log/diff,
dependency and config movement), then run one-hypothesis-one-experiment
cycles, bisecting when hypotheses run out. One variable per attempt; no fix
may precede the diagnosis; after three failed fix cycles stop and question the
diagnosis level instead of trying a fourth.

Dispatch, unless the triage is trivially settled in one read: hand the
investigation to this plugin's own `debugging:debugger` agent rather than running
the hypothesis cycles in the main thread. A bisection burns context proportional
to how confused the run is, which is exactly the context the main thread needs to
apply the fix afterwards. The agent returns the diagnosis and the minimal fix; it
does not decide whether to ship it.

Then route the proven fix down `task-runner:task-executor if installed → inline`,
the same chain every review command in this marketplace uses — a diagnosis that
ends in chat is a diagnosis the user has to re-type.

Report: the root cause with its evidence chain, the fix and why it follows
from the diagnosis, verification output (the original reproduction passing
plus the full suite), and the regression test added from the repro. If the
root cause was NOT found, say so explicitly, list what was ruled out with
evidence, and label any mitigation as a symptom fix — never ship a guess
labeled as a fix.
