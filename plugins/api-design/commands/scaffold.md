---
description: Scaffold Laravel routes, FormRequests, and API Resources from an approved OpenAPI spec (spec-first)
argument-hint: [openapi-spec-path]
---

Turn an approved API design into implementation scaffolding — the spec-first path that
picks up where /api-design:review's approved spec leaves off, instead of re-deriving the
route→request→resource mapping by hand.

1. Locate the spec from $ARGUMENTS — an OpenAPI/Swagger file, or the approved design doc
   from a prior /api-design:review. If empty, ask for the spec path. Invoke the
   `api-design` skill so the generated code honors its conventions (status codes,
   pagination, RFC 9457 errors, versioning).

2. Detect the stack. For Laravel (the default here), map each spec operation to:
   - a **route** in the correct api version group with the right verb and path;
   - a **FormRequest** with validation rules derived from the request schema
     (types, required, formats, enums) and an authorize() stub;
   - an **API Resource** (and ResourceCollection) shaped to the response schema;
   - a **controller** action wired to the above, with a typed return.
   For a non-Laravel stack, produce the equivalent (router + validation + serializer).

3. Generate additively and idempotently: do not overwrite an existing handler — emit new
   files, and for existing ones show the diff to apply. Preserve the project's naming and
   directory conventions (read a sibling controller/request first).

4. Report the mapping table — operation → route → FormRequest → Resource → controller —
   so the spec-to-code correspondence is auditable, plus any spec gap that blocked
   generation (an operation with no response schema).

5. Offer via AskUserQuestion: "Write the scaffolding now (Recommended)" / "Show the plan
   only". On write, dispatch the `backend-engineer` worker with the mapping as the task
   list. Headless: output the mapping and files as a plan, write nothing.
