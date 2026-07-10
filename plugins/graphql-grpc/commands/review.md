---
description: Review a GraphQL or gRPC API for N+1, resolver authz, query limits, proto compatibility, and deadlines against graphql-grpc
argument-hint: [path-schema-proto-or-diff]
---

Review the target GraphQL or gRPC API — the failure modes are distinct from REST.

1. Determine scope from $ARGUMENTS — a GraphQL schema + resolvers, a `.proto` +
   service impl, or a diff. If empty, locate the schema/proto and its resolvers/handlers
   in the repo and review those. Detect which paradigm is in play.

2. Invoke the `graphql-grpc` skill from this plugin and apply the matching checklist.
   GraphQL: DataLoader batching on every relationship resolver (no N+1), per-field/object
   authorization against the viewer, query depth/complexity caps, cursor pagination,
   typed error codes with no leaked internals, introspection gated in prod. gRPC: no
   reused/renumbered field tags (retired ones `reserved`), optional-with-default new
   fields for rolling compatibility, deadlines set and propagated on every call, stream
   flow control + termination, canonical status codes.

3. Output findings one line each:
   path:line — severity — problem — fix
   Order by severity. An N+1 resolver, missing per-field authz, an unbounded query, a
   reused proto field number, or a deadline-less call are the critical classes.

4. Defer, do not duplicate: REST design → `/api-design:review`; the datastore query a
   resolver runs → `/database:review`; token/scope auth → `/api-auth:review`.

5. When findings exist, offer the next step as a selectable choice (AskUserQuestion):
   "Apply the fixes now (Recommended)" / "Report only". On apply, hand the finding list
   to the shared `task-executor`. In headless or non-interactive runs, report only.
