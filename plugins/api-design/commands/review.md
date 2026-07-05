---
description: Review API routes, controllers, or OpenAPI specs against api-design
argument-hint: [files-or-diff]
---

Review the API surface in $ARGUMENTS (or the current diff if no argument) against the
api-design skill from this plugin. Invoke the skill first. Look at route files,
controllers, FormRequests, API Resources, and OpenAPI/JSON Schema specs — judge the
contract the consumer sees (paths, methods, status codes, error shape, pagination,
filtering, versioning, idempotency), not internal code style. When uncertain about
semantics, verify against the RFCs (9110 for methods/status codes, 9457 for problem
details) instead of answering from memory. Report findings as
`path:line — problem — fix`, ordered by severity. Skip naming nits unless they leak
into the public contract.
