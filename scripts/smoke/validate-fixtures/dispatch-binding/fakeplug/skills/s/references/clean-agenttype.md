Fan out one `worker` per item.

```
parallel(items.map(i => () => agent(workerPrompt(i), {schema: OUT, agentType: 'fakeplug:worker'})))
```
