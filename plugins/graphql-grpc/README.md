# graphql-grpc

Two API paradigms REST habits fail on.

- **`graphql-grpc` skill** — GraphQL: the N+1/DataLoader default, per-field resolver
  authorization, query depth/complexity limits, cursor pagination, error shaping,
  introspection gating. gRPC: proto field-number safety, rolling-compatible evolution,
  streaming with flow control, mandatory propagated deadlines, canonical status codes.
  Includes a which-paradigm decision aid.
- **`/graphql-grpc:review`** — audit a schema/proto and its resolvers/handlers for the
  critical classes: N+1, missing per-field authz, unbounded queries, reused proto tags,
  deadline-less calls.

Defers REST design to api-design, the datastore query to database, and token auth to
api-auth.
