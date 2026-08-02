# pgvector: the failures that present as relevance problems

> Last verified: 2026-08-02 — https://github.com/pgvector/pgvector

Every item here is a CORRECTNESS bug that looks like a quality complaint. That is
what makes them worth writing down: the query returns rows, the tests pass on a
thousand-row fixture, and the only symptom is that results are slightly worse than
someone expected — which gets attributed to the embedding model, the chunking, or
the prompt. None of them raise an error.

## The operator class must match the model's distance metric

An index is built for ONE distance operator. Build it with `vector_l2_ops` and
query with `<=>` (cosine) and Postgres will not use the index — it falls back to a
sequential scan, silently. Fast on test data, unusable in production, and `EXPLAIN`
is the only thing that says so.

| Query operator | Metric | Operator class |
|---|---|---|
| `<=>` | cosine distance | `vector_cosine_ops` |
| `<->` | L2 / Euclidean | `vector_l2_ops` |
| `<#>` | negative inner product | `vector_ip_ops` |

The metric is decided by the EMBEDDING MODEL, not by preference. Most text
embedding models are trained for cosine similarity; using L2 against them is not
an optimisation choice, it is a different question.

    CREATE INDEX ON docs USING hnsw (embedding vector_cosine_ops);

Verify with `EXPLAIN ANALYZE` that the plan says `Index Scan using …`. If it says
`Seq Scan`, the opclass and the operator disagree.

## Filtered ANN silently returns fewer and worse rows

This is the one that costs the most and is understood the least:

    SELECT * FROM docs
    WHERE tenant_id = $1
    ORDER BY embedding <=> $2
    LIMIT 10;

The index returns its candidate set FIRST, then the `WHERE` filters it. Ask for 10
and the index yields its candidates; if only three of them belong to that tenant,
you get three rows — not the ten nearest documents for that tenant. The more
selective the filter, the worse it gets, and on small test data every candidate
passes the filter so the bug is invisible until a tenant is small relative to the
corpus.

Three real fixes, in order of preference:

1. **Iterative scan** (pgvector 0.8+): `SET hnsw.iterative_scan = relaxed_order;`
   — the index keeps producing candidates until enough survive the filter. Also
   set `hnsw.max_scan_tuples` so a filter matching almost nothing cannot scan the
   whole table.
2. **Partition by the filter column** when the filter is always the same one
   (tenant, workspace). Each partition gets its own index and the filter becomes
   partition selection rather than post-filtering.
3. **Over-fetch and re-filter** in the application — request `LIMIT 100`, filter,
   take 10. Crude, honest, and correct as long as the over-fetch factor is
   justified by the data rather than guessed.

Note what does NOT fix it: a B-tree index on `tenant_id`. The problem is ordering,
not lookup.

## `ef_search` is a per-session recall dial, not a constant

`hnsw.ef_search` (default 40) controls how many candidates the search considers.
Raising it improves recall and costs latency; it is a session/transaction GUC, so
it can differ per query class — high for a "find everything relevant" report, low
for a typeahead. Tuning it is measurement, not taste: fix a query set, vary
`ef_search`, and plot recall against p95. `ivfflat` has the analogous
`ivfflat.probes`.

## Dimensions, and the 2000-column ceiling

`vector` indexes cap at 2000 dimensions. Above that: `halfvec` (16-bit floats,
half the storage, 4000-dimension index ceiling) with an optional exact re-rank
against the full-precision column, or dimensionality reduction if the model
supports Matryoshka truncation. Storing a 3072-dimension vector and then
discovering it cannot be indexed is a migration, not a config change.

## Changing the embedding model invalidates every stored vector

Vectors from two different models are not comparable — not "less accurate",
incomparable. Switching models is a **backfill**: new column or new table, re-embed
every row, cut over, drop the old. Plan it as a data migration with a dual-write
window, and never as a config swap. The failure mode of getting this wrong is
retrieval that quietly returns near-random rows for the un-migrated fraction of the
corpus.

## Checklist for a review

- Does the opclass match the operator the query actually uses?
- Is there a `WHERE` on the same statement as `ORDER BY embedding <=> …`? If so,
  is iterative scan, partitioning, or over-fetch in place?
- Is `ef_search`/`probes` set deliberately anywhere, or left at the default with no
  recall measurement?
- Is the dimension count under the index ceiling for the chosen type?
- Does anything document which model produced the stored vectors? Without that, a
  future model change cannot be planned safely.
