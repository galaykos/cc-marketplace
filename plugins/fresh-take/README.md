# fresh-take

An `/advisor`-style "fresh take" for key moments: an independent, stronger-model
second opinion you can pull into a session exactly when it matters.

## The two moments

- **Stuck debugging** — the same fix has failed repeatedly and the session is
  looping on one hypothesis.
- **Irreversible decisions** — a destructive or one-way action is imminent:
  dropping a table, force-pushing, rewriting history, deleting data.

## The two triggers

- **Explicit:** `/fresh-take:consult [topic]` — composes a facts-only consult
  brief and dispatches the `consultant` agent (stronger-model, read-only repo access).
- **Passive:** a one-line `UserPromptSubmit` nudge when a prompt contains
  key-moment phrases ("still failing", "force push", …). The nudge only
  suggests the command; it may repeat on later matching prompts.

## The hard promise

Advice only. The consultant returns a `Take`, `Risks`, and one `Alternative` —
and nothing else. It never blocks an action, never gates a run, never writes
code or files. The brief deliberately omits the session's own leaning, so the
opinion is formed blind from the code, not anchored to the thread's hypothesis.

## The blind rule's teeth

The brief must not carry the session's conclusion — and the session composing it is
the party with the anchor, so since 0.3.0 `scripts/brief-lint.sh` (fixture harness in
CI) rejects conclusion phrasing mechanically; the skill requires a clean exit before
dispatch. Residual, stated in the lint itself: it catches phrasing, not a hypothesis
smuggled as a neutral fact — the reread stays on the session.

## Cost shape

One consultant per consult — never a panel. If you want adversarial voting,
compose the orchestration plugin's verification-panels yourself.

## Suite membership

None — standalone by design (recorded; nothing enforces this). fresh-take
ships a UserPromptSubmit reminder hook and dispatches a stronger-model
consultant on demand; both are deliberate opt-ins a bundle would install
silently. Install it alone, when you want the second opinion.
