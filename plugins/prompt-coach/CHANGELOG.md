# Changelog

All notable changes to the `prompt-coach` plugin.

## 0.1.0 — 2026-10-07

- **First release: the manifest, its options and the state contract.** Three `/config`
  options, each overridden by its variable: `cc_prompt_coach` (`CC_PROMPT_COACH`, on),
  `cc_coach_model` (`CC_COACH_MODEL`, `sonnet` or `opus`, default `sonnet`) and
  `cc_coach_sensitivity` (`CC_COACH_SENSITIVITY`, `unactionable` or `ambiguous`, default
  `unactionable`). `types/index.d.ts` declares the session state the coach keeps.
