---
name: meta-api
description: Use when a task touches any Meta developer platform — Facebook Graph API, Pages, Facebook Login, Instagram, WhatsApp Business, Messenger, Marketing API, or webhooks. Resolves the CURRENT API version from the changelog before writing anything, navigates via a predefined doc-link map, applies platform conventions (tokens, fields, cursor pagination, error codes), and answers which permissions and App Review access level a feature needs.
---

## Memory is stale here by design

Graph API versions ship quarterly and each lives ~2 years; permissions get
renamed, products get retired (Instagram Basic Display died 2024 — answering
from memory recommends a dead API). Every version literal, permission name, and
endpoint in your output must come from a page fetched THIS session, not recall.
If developers.facebook.com is unreachable, say so and ask for a docs excerpt —
never fill the gap from memory.

## Resolving the current version

- Fetch https://developers.facebook.com/docs/graph-api/changelog — the top
  entry is the latest version; the table shows each version's expiry.
- Version rides the URL path: `/v23.0/{node}`. Unversioned calls pin to the
  app's default (its creation-era version) — that is a trap, not a feature:
  always write the version explicitly.
- The Marketing API versions separately (own changelog under
  /docs/marketing-api/) — do not assume it matches Graph.
- Grep the codebase for `/v[0-9]+\.[0-9]+/` and SDK pins
  (`facebook/php-business-sdk`, `facebook-nodejs-business-sdk` in lockfiles);
  flag anything at or past the changelog's expiry date.

## The link map

Start from the product page, not search — fetch and follow from these roots;
if a path 404s (Meta reshuffles docs), recover from https://developers.facebook.com/docs/:

| Task smells like | Start here (under /docs/) |
|---|---|
| Reading/writing graph data | graph-api/ (reference: graph-api/reference/) |
| Login, tokens, OAuth flows | facebook-login/ (tokens: facebook-login/guides/access-tokens) |
| Page publishing, insights | pages-api/ |
| Instagram content, DMs, insights | instagram-platform/ |
| WhatsApp messaging | whatsapp/cloud-api/ |
| Messenger bots | messenger-platform/ |
| Ads, audiences, campaigns | marketing-apis/ |
| Real-time updates | graph-api/webhooks/ |
| Permission catalogue | permissions/ |
| Review process, access levels | app-review/ |
| Errors and rate limits | graph-api/guides/error-handling, graph-api/overview/rate-limiting |

## Graph conventions

- Everything is nodes, edges, fields: `GET /v23.0/{page-id}/posts?fields=id,message,created_time`.
  Always pass `fields=` — the no-fields default is sparse AND unstable across
  versions; explicit selection is both the contract and the performance fix.
- Pagination is cursors: follow `paging.next` or pass `after=` — never offset
  arithmetic; cursors expire, so paginate promptly and don't store them.
- Batch up to 50 calls via the `batch` parameter when fan-out is needed;
  each sub-request still counts against rate limits.
- Errors come as `{"error": {"code", "error_subcode", "type", "fbtrace_id"}}`.
  The load-bearing codes: 190 invalid/expired token (subcode narrows: 463
  expired, 460 password change), 4/17/32 rate limits (app/user/page — back off,
  do not retry-storm), 10 and 200–299 missing permission, 100 invalid parameter.
  Log `fbtrace_id` — Meta support is useless without it.
- Rate-limit state rides response headers (`X-App-Usage`, `X-Business-Use-Case-Usage`)
  — read them and slow down BEFORE hitting the wall.

## Token types — pick the right one

- **User token**: short-lived from login → exchange for 60-day long-lived
  server-side. Personal-scope actions only.
- **Page token**: derived from a user token holding the page role; required for
  acting AS a page. Long-lived user token yields non-expiring page tokens.
- **System user token** (Business Manager): the right choice for server
  integrations — no human session to expire.
- **App token / client token**: app-level config and limited client-side use;
  an app secret or app token in frontend code is a security finding, full stop.
- Server-side calls should send `appsecret_proof` (HMAC-SHA256 of the token
  with the app secret); debug any token via `GET /debug_token`.

## Answering "which permissions do I need"

The question every Meta task eventually asks. Protocol:

1. Find the endpoint's reference page — its **Permissions** section is the
   authoritative list (per endpoint, sometimes per field).
2. Cross-check the name in the permissions catalogue (permissions/) — it lists
   every permission's App Review requirement and allowed usage.
3. Report the ACCESS LEVEL with the name: Standard Access (works for app-role
   users immediately) vs Advanced Access (App Review + often business
   verification before it works for the public).
4. State the mode gap explicitly: in Development mode everything works for
   admins/developers/testers — the classic "works for me, dies at launch" trap
   is shipping without Advanced Access.
5. Request the MINIMAL set. Every extra permission is App Review surface and a
   rejection risk; "might need it later" is how reviews fail.

Typical shapes (verify names against the catalogue before asserting):
page publishing wants `pages_manage_posts` + `pages_read_engagement`;
Instagram publishing wants `instagram_basic` + `instagram_content_publish`;
anything beyond `public_profile`/`email` at launch means App Review.

## Webhooks

- Subscription handshake: echo `hub.challenge` back on the GET verify request
  after checking `hub.verify_token` matches yours.
- Validate every delivery with `X-Hub-Signature-256` (HMAC-SHA256, app secret)
  — an unvalidated webhook endpoint accepts forged events from anyone.
- Webhooks deliver deltas, not state: on receipt, re-fetch the object for
  truth; deliveries can arrive late, duplicated, or out of order.

## Anti-patterns

- Any version, permission, or endpoint written from memory instead of a fetched
  page — this platform's docs churn is the whole reason this skill exists.
- Unversioned API paths riding the app's default version.
- `fields`-less GETs, offset-style pagination, stored cursors.
- Requesting broad permissions "to be safe" — App Review rejects unjustified
  scopes and the review text must cite each one's usage.
- Polling an edge that has a webhook topic.
- App secret, app token, or `appsecret_proof` computation in client code.
- Treating a Development-mode success as launch-ready without checking the
  Advanced Access column.
