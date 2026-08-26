# product-suite

Meta-bundle: the product-domain disciplines in one install — payments and
billing, and LLM application engineering. Each member is
a domain skill plus a review command; the failure classes they guard
(double-charges, unevaluated prompts) sit in product code, not
in any one stack. Uninstalls cleanly: `/product-suite:uninstall` removes the
bundle and prunes the plugins it auto-installed.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install product-suite@cc-plugins-marketplace
```

## What's included

- **payments** — payments and billing discipline (Stripe/Paddle/Braintree):
  tokenized PCI scope, integer-minor-unit money, signature-verified idempotent
  webhooks, subscription state machines, append-only ledger, plus
  `/payments:review`
- **llm-app** — LLM application engineering: eval harnesses and regression
  gates, RAG pipelines, prompt versioning, prompt-injection defense,
  token-cost control, plus `/llm-app:review`

| Command | What it does |
|---------|--------------|
| `/product-suite:uninstall` | Uninstall the bundle AND prune every plugin it auto-installed — one step, no orphans; manually installed plugins are never touched |

## Pairs well with

- **security** — the boundary and secrets side of payment and LLM surfaces
- **api-design** — the endpoint contracts these domains ship behind
- **testing** — the regression harnesses the domain rules assume exist
