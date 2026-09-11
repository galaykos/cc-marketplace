# pgvector — the rules that silently disable the index

> Last verified: not fetched — written 2026-09-10 from training knowledge (model cutoff
> June 2026) against https://github.com/pgvector/pgvector, assuming the 0.8.x line. No
> live re-read was done; run the `digest-refresh` project skill before trusting a
> version-pinned claim. Check the installed line first:
> `SELECT extversion FROM pg_extension WHERE extname = 'vector';` — managed Postgres
> (RDS, Cloud SQL, Supabase) often lags upstream by a minor.

Standing: **recorded** — `/database:review` loads this file when a diff touches a
`vector` column or `USING hnsw|ivfflat`; nothing scripts the rules below.

## Column types and dimension pinning

- `vector(1536)`, never bare `vector`: an undimensioned column stores anything and
  **cannot be indexed** (`column does not have dimensions`). The dimension is the
  embedding model's contract — a second model with a different width needs a new
  column, not a wider one.
- Index ceilings (as of 0.8): `vector` indexes up to **2,000** dims, `halfvec` up to
  4,000, `bit` up to 64,000, `sparsevec` up to 1,000 non-zero entries. A 3,072-dim
  embedding (e.g. `text-embedding-3-large` at full width) in `vector(3072)` stores fine
  and then fails at `CREATE INDEX`. Either request fewer dims from the model or index
  the half-precision cast — and query through the SAME cast, or the index is skipped:

      CREATE INDEX ON docs USING hnsw ((embedding::halfvec(3072)) halfvec_cosine_ops);
      SELECT id FROM docs ORDER BY embedding::halfvec(3072) <=> $1::halfvec(3072) LIMIT 10;

- `halfvec`, `sparsevec`, `bit` opclasses and the L1 operator arrived in **0.7.0**;
  HNSW itself in **0.5.0** — a server on 0.4 has IVFFlat only. Version the claim.
- Changing the embedding model = re-embed every row and rebuild the index. Vectors
  from two models are not comparable even at equal width. Record the model name and
  version next to the column (a `model` column or a per-model column) so a partial
  backfill is visible, and dual-write during the swap the way any column migration does.

## Operators, opclasses, and the mismatch that costs the index

| operator | distance | opclass (vector / halfvec) | order by |
|---|---|---|---|
| `<->` | L2 (Euclidean) | `vector_l2_ops` / `halfvec_l2_ops` | ASC |
| `<=>` | cosine distance = 1 − cosine similarity | `vector_cosine_ops` / `halfvec_cosine_ops` | ASC |
| `<#>` | **negative** inner product | `vector_ip_ops` / `halfvec_ip_ops` | ASC |
| `<+>` | L1 / taxicab (0.7+) | `vector_l1_ops` (HNSW only) | ASC |
| `<~>` / `<%>` | Hamming / Jaccard on `bit` (0.7+) | `bit_hamming_ops` / `bit_jaccard_ops` | ASC |

- **An index serves exactly one operator.** An HNSW index built with `vector_l2_ops`
  is silently ignored by `ORDER BY embedding <=> $1`; the query still returns correct
  rows via a sequential scan, so nothing fails until the table is large. `vector_l2_ops`
  is the **default opclass** — `USING hnsw (embedding)` with no opclass named builds an
  L2 index, which is wrong for every cosine-shaped workload. Always name the opclass.
- The index fires only on `ORDER BY <column> <op> <param> [ASC] LIMIT k`. A distance
  predicate in `WHERE` (`embedding <=> $1 < 0.3`), `ORDER BY 1 - (embedding <=> $1)
  DESC`, or the operator wrapped in a function is a full scan. Compute similarity in the
  SELECT list; sort by the raw distance.
- `<#>` returns the inner product **negated** so ASC ordering works; multiply by −1 in
  the SELECT list for the real value. Inner product is only a sane ranking for
  unit-length vectors.

## Normalisation for cosine

`vector_cosine_ops` normalises internally, so unnormalised vectors are correct, just
slower. If the model emits unit vectors (OpenAI's do; many do not — check, do not assume),
`<#>` with `vector_ip_ops` gives the same ranking cheaper. A zero vector has no
direction: reject or NULL it at insert instead of letting it rank against everything.

## HNSW vs IVFFlat — when each is the wrong choice

|  | HNSW | IVFFlat |
|---|---|---|
| build | slow, memory-heavy (graph must fit `maintenance_work_mem` or the build crawls — the server logs a NOTICE when it stops fitting); parallel from 0.6 | fast, light |
| needs data first | no — build empty, insert freely | **yes** — centroids are trained from the rows present at build time |
| recall over time | stable | degrades as data drifts from the training centroids; `REINDEX` after major growth |
| query tuning | `hnsw.ef_search` (default 40) | `ivfflat.probes` (default **1**) |

- IVFFlat is wrong when the table is empty or small at build time (a migration that
  creates the index before the backfill trains centroids on nothing), and when the
  distribution shifts (new tenants, new document types). HNSW is wrong only when the
  build budget is the constraint — a multi-hundred-million-row table with tight memory.
- HNSW build params: `m` (default 16) and `ef_construction` (default 64);
  `ef_construction` must be ≥ 2 × `m` or the build errors. Raise both for recall at
  the cost of build time and index size; they cannot be changed without a rebuild.
- IVFFlat `lists`: rows / 1,000 up to ~1M rows, `sqrt(rows)` above. Query-time
  `probes` at the default of 1 visits one cell — recall is poor until it is raised
  (rule of thumb `sqrt(lists)`); `probes = lists` is an exact scan.

## `ef_search`, `probes` and the result cap

- **HNSW returns at most `hnsw.ef_search` rows.** `LIMIT 100` with the default 40
  returns 40 rows and no error. Set it per transaction, sized to the largest LIMIT plus
  the filter loss below: `SET LOCAL hnsw.ef_search = 200;`.
- The `SET` must reach the same connection as the query — a pooled connection with a
  session-level `SET` leaks the value to the next tenant's query. `SET LOCAL` inside the
  transaction that runs the search.

## Filtering before vs after ANN — "the filter kills recall"

`WHERE tenant_id = 7 ORDER BY embedding <=> $1 LIMIT 10` is the common RAG shape, and
the planner has two bad options. Via the HNSW index it fetches `ef_search` nearest
candidates across ALL tenants and applies the filter afterward — a tenant holding 1%
of rows gets ~0 of 40 candidates back, so the query returns **fewer than 10 rows, or
none**, with no error. Via the btree on `tenant_id` it does an exact scan of the
tenant's rows — correct, and fine until a tenant is large. Answers, in order of reach:

1. **Iterative scans (0.8.0+)** — `SET LOCAL hnsw.iterative_scan = relaxed_order;`
   keeps walking the graph until the LIMIT is satisfied post-filter, bounded by
   `hnsw.max_scan_tuples` (default 20,000). `strict_order` costs more; `off` is the
   default, so a 0.8 server behaves like 0.7 until this is set. IVFFlat has the
   matching `ivfflat.iterative_scan` and `ivfflat.max_probes`.
2. **Partial index per selective filter** — `CREATE INDEX ... USING hnsw (...)
   WHERE tenant_id = 7` for a handful of large tenants or a `status = 'live'` flag; the
   filter is then inside the index. Does not scale to thousands of tenants.
3. **Pre-filter into a small set and search exactly** — when the filtered set is
   small (a user's own documents), let the btree win and skip ANN entirely.
4. Raise `ef_search` proportionally to filter selectivity — a stopgap, not a fix: it
   is a linear cost increase against a geometric loss.

## What EXPLAIN shows

    EXPLAIN (ANALYZE, BUFFERS) SELECT id FROM docs ORDER BY embedding <=> $1 LIMIT 10;

- Index used: `Index Scan using docs_embedding_idx on docs` with `Order By: (embedding
  <=> $1)`. Anything else — `Sort` over a `Seq Scan` or `Gather` + `Parallel Seq Scan`
  with a `top-N heapsort` — is a full scan: wrong opclass, wrong operator, a cast that
  does not match the index expression, or a table small enough that the planner is
  right to skip the index (do not "fix" that with `enable_seqscan = off` in production).
- Recall has no EXPLAIN line. Measure it on a sample: run the query with the index,
  then with `SET LOCAL enable_indexscan = off` (exact), and compare the id sets. Under
  ~0.9 overlap, raise `ef_search` / `probes` or enable iterative scans; if it is a
  filtered query, the collapse above is the cause before the tuning is.
- `CREATE INDEX CONCURRENTLY` is fine for both methods; watch
  `pg_stat_progress_create_index` — an HNSW build that exceeded `maintenance_work_mem`
  shows the phase stuck for hours, not failed.
