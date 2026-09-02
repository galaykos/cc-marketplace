# Galera clustering — the failure vocabulary

> Last verified: 2026-08-12 — https://mariadb.com/kb/en/galera-cluster/
> Galera semantics are stable across 10.x–12.x; the traps below are model-level,
> not version-level.

The SKILL's one paragraph says "certification failures are retryable." This file is
what that actually means operationally — the part where Galera-naive advice (written
for a single primary) silently corrupts expectations.

## Certification failure ≠ deadlock, but wears its error code

- Galera is multi-master with OPTIMISTIC certification: transactions run locally
  without cluster locks and are certified at COMMIT against write-sets from other
  nodes. A conflict surfaces as **error 1213 (deadlock) AT COMMIT TIME** — not as a
  lock wait during the transaction.
- Consequence one: code that only handles deadlocks around `UPDATE` statements misses
  it — the retry must wrap the WHOLE transaction including the commit.
- Consequence two: `SELECT ... FOR UPDATE` does NOT lock rows on other nodes. Two
  nodes can both "acquire" the same row lock and one dies at commit. Pessimistic
  locking patterns port to Galera as race conditions wearing a seatbelt.
- Mitigation that actually works: route hot-row writers (counters, queues, inventory
  decrements) to ONE node (proxy-level read/write split or per-table routing), keep
  transactions small, and treat 1213 as always-retryable with jittered backoff.

## Flow control — the whole cluster runs at the slowest node's pace

- Each node applies replicated write-sets asynchronously with a bounded queue. A node
  falling behind emits flow-control messages that PAUSE the entire cluster's commits.
- Symptom: cluster-wide commit latency spikes with no slow query anywhere on the node
  you are looking at. Check `wsrep_flow_control_paused` on EVERY node — the culprit is
  the one applying slowly (cold buffer pool, weaker hardware, a backup running).
- A large transaction (the SKILL's chunked-backfill rule) is amplified: the write-set
  replicates whole, certifies whole, applies whole on every node. Batch in thousands,
  not millions.

## Joining and recovery — SST vs IST

- **IST** (incremental): a rejoining node replays the gap from a donor's cache
  (`gcache`) — fast, non-blocking. Works only while the gap still fits the donor's
  gcache window; size `gcache.size` to survive your longest expected outage.
- **SST** (full snapshot): the fallback — a full data copy that loads a donor node
  for the duration. An undersized gcache turns every maintenance window into an SST
  storm. If nodes routinely SST after brief restarts, gcache is too small.

## Quorum and split-brain

- The cluster requires a PRIMARY COMPONENT: >50% of nodes (weighted, `pc.weight`).
  A two-node cluster therefore cannot survive either node failing cleanly — the
  survivor loses quorum and refuses writes. Minimum honest deployment is 3 nodes or
  2 + garbd (arbitrator daemon, votes without storing data).
- A non-primary partition answers reads (stale) and refuses writes with
  `WSREP has not yet prepared node for application use` — application error handling
  must distinguish this (fail over) from a query bug (do not retry forever).
- WAN clusters: use `gmcast.segment` so replication crosses the WAN once per segment,
  and expect commit latency ≈ the slowest inter-segment RTT — Galera commits are
  synchronous to certification on every node.

## DDL — two modes, pick per migration

- **TOI** (total order, default): the DDL runs on every node at the same point in the
  replication stream — cluster-wide metadata lock; every node stalls for the DDL's
  duration. Fine for small tables, disastrous for a 500 GB ALTER.
- **RSU** (rolling): the DDL runs node-by-node with the node desynced from
  replication — no cluster stall, but YOU guarantee the schema change is
  backward-compatible with in-flight write-sets (the SKILL's expand→contract
  discipline is mandatory, not advisory, under RSU).
- The SKILL's "schema changes need a strategy chosen, not defaulted" bullet means:
  name TOI or RSU in the migration plan, with the table size that justified it.

## When NOT to apply this file

Not on a single-node MariaDB or primary-replica setup — GTID replication rules in the
SKILL body cover those; Galera vocabulary there is noise. Detect first:
`SHOW STATUS LIKE 'wsrep_cluster_size'` > 0 means Galera is live.
