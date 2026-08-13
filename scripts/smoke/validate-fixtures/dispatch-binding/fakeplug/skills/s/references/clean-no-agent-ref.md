Generic reasoning fan-out; no shipped agent is named, so the default subagent is correct.

```
parallel([1,2,3].map(() => () => agent(refutePrompt(claim), {schema: VERDICT})))
```
