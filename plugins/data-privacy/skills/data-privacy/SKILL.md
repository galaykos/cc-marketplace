---
name: data-privacy
description: Use when handling personal data or building for GDPR/CCPA compliance — PII classification and data mapping, the data-subject rights (access, erasure, portability), consent capture, retention and deletion policies, data minimization, pseudonymization, and audit trails. The regulatory data-handling layer above code-level security review.
---

# Data privacy & compliance

Privacy law treats personal data as something you are a custodian of, not an owner —
you must know what you hold, why, for how long, and be able to hand it back or delete
it on request. This is a *design* concern: a system that cannot answer "where is all
of this person's data" cannot comply, and that answer must be built in, not archaeology.

## Know your data (the map)

You cannot protect or delete what you have not mapped. Maintain a **data inventory**:
what personal data is collected, where it is stored (every table, log, cache, backup,
third-party processor), why (the lawful basis / purpose), and how long it is kept. This
map is the foundation for every right below; without it, "delete my data" is a guess.

- **Classify** — distinguish PII (name, email, IP) from **sensitive/special-category**
  data (health, biometrics, religion, sexual orientation) which carries stricter rules.
- **Minimize** — collect only what a stated purpose needs. Data you never collected is
  data you never have to protect, disclose, or delete. "We might use it later" is not a
  purpose.

## Data-subject rights — build the mechanisms

The law grants individuals rights your system must be able to honor, usually within a
deadline (GDPR: 30 days):

- **Access / portability** — export all of a person's data in a portable format. Needs
  the data map to be complete, including derived data and third-party copies.
- **Erasure ("right to be forgotten")** — delete on request, across primary stores,
  logs, caches, backups, and processors. Design *how* backups are handled (crypto-shred,
  or a documented rolling-expiry) — "it's in an immutable backup" is not an exemption you
  can assume.
- **Rectification** — correct inaccurate data, propagated to copies.
- **Object / restrict** — stop processing for a purpose (e.g. marketing) while retaining
  for another (e.g. legal).

An erasure that leaves the email in application logs and a third-party analytics tool is
not erasure.

## Consent and lawful basis

- **Consent is specific, informed, freely given, and revocable** — no pre-ticked boxes,
  no bundling ("agree to everything to use the app"), and withdrawing must be as easy as
  giving. Record what was consented to, when, and the version of the terms.
- Consent is only one lawful basis; contract, legal obligation, and legitimate interest
  are others. Name the basis per processing purpose — you cannot switch bases after the
  fact to justify a use.

## Retention and deletion

Every category of data has a **retention period** tied to its purpose, and an automated
deletion or anonymization when it expires. "Keep everything forever" is a liability that
grows with every breach's blast radius. Prefer **pseudonymization/anonymization** where
you need the analytics but not the identity — truly anonymized data falls outside the
regime.

## Audit trail

Access to personal data — especially sensitive categories — is logged: who accessed
what, when, why. The audit log itself is personal data (subject to retention) and must
not become a secondary leak (no full records copied into logs).

## Designing a feature that touches personal data

Before writing it, answer four questions — they are the mini data-protection assessment:

1. **What** personal data does this collect, and is any of it special-category?
2. **Why** — the specific purpose and the lawful basis for it.
3. **How long** is it kept, and what deletes/anonymizes it when that expires?
4. **Who/what** else receives it (third-party processors), and are they covered?

If any answer is "unclear", that is the finding — resolve it before building, because
retrofitting deletion and export across a system that never planned for them is far
harder than designing them in.

## Reviewing for privacy

- A data map exists and this change updates it (new field, new store, new processor).
- Only purpose-necessary data is collected; no speculative hoarding.
- Access, export, and erasure can reach this data — including logs, caches, backups,
  and third parties.
- Consent (where it's the basis) is specific, unbundled, recorded, and revocable.
- A retention period and an automated deletion/anonymization exist.
- Sensitive categories are classified and handled under stricter rules.

## Defer rule

- Code-level security (injection, authz enforcement, encryption in transit/at rest) →
  `/security:review`; this skill owns the regulatory data-handling, not the exploit.
- Secret/credential handling → `secret-scanning`.
- Where deletion touches schema and cascade design → `database-design`.

## Anti-patterns

- **No data map** — cannot answer access/erasure because no one knows where data lives.
- **Collect-everything** — data hoarded without a purpose, all of it a breach liability.
- **Erasure that misses copies** — logs, caches, backups, and processors left intact.
- **Pre-ticked / bundled consent** — not freely given; invalid under GDPR.
- **No retention policy** — everything kept forever, blast radius only growing.
- **Sensitive data unclassified** — special-category data handled like ordinary PII.
- **Cross-border transfer ignored** — moving EU data to a region without an adequacy
  decision or safeguards; a compliance gap invisible until audited.
