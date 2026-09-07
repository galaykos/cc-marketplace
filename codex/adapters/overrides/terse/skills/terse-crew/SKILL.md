---
name: terse-crew
description: Use when choosing concise investigation, implementation, or review delegation and defining an evidence-preserving return format.
---

# Choose the role and receipt

| Need | Role | Return contract |
| --- | --- | --- |
| Locate symbols, callers, usages | Investigator | `path:line — symbol — finding`, or `No match.` |
| Decided edit in one or two files | Builder | changed paths/lines, verify command/result, remaining work |
| Quick diff inspection | Reviewer | `path:line: severity: problem. fix.` ordered by severity |
| Complex implementation | Task executor | task status, actual diff, verification evidence, blockers |
| Deep review or architectural explanation | Domain reviewer | findings with reasoning, evidence, and tradeoffs |

Use delegation only when a concrete independent task justifies it and the session's tools/policy permit it. Discover actual tool schemas and available skill instructions; these role labels are not assumed Codex agent types. Pass the role instructions explicitly, inherit the session model, and include full absolute paths, scope, conventions, verification obligations, and the return contract. Do not compress the outgoing task brief.

If delegation is unavailable, perform the selected role inline and use the same receipt format. If the answer is already known, answer directly. Read the available delegation-contracts skill when present for additional dispatch conventions. Compression saves the caller's return-context space; it does not establish lower worker cost or permit removing evidence needed to assess a claim.
