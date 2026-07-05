# meta-api

Meta (Facebook) developer platform navigator. The platform's docs churn
quarterly — Graph API versions rotate, permissions get renamed, whole products
retire — so this plugin's rule is absolute: every version, permission, and
endpoint comes from a page fetched in the current session, never from memory.

Covers Facebook Graph API, Pages, Facebook Login, Instagram Platform, WhatsApp
Business (Cloud API), Messenger, Marketing API, and webhooks.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install meta-api@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/meta-api:check [task-endpoint-or-product]` | Resolve the current API version, exact endpoints, **required permissions with access level** (Standard vs Advanced / App Review), the right token type, and rate/pagination constraints — all doc-backed |

## Example

```bash
/meta-api:check schedule posts to a Facebook page and cross-post to Instagram
```

Reports something like: current Graph version to pin, the `/{page-id}/feed`
and Instagram publishing endpoints, `pages_manage_posts` +
`pages_read_engagement` + `instagram_basic` + `instagram_content_publish`
(Advanced Access → App Review required), page token via long-lived user token,
and the works-only-for-app-roles warning for Development mode.

## What the skill enforces

- Current version from the changelog, never memory; hardcoded `/vXX.X/` paths
  and SDK pins in the codebase flagged when at/past expiry
- Predefined link map per product area, with 404 recovery from the docs root
- Graph conventions: explicit `fields=`, cursor pagination, batch limits,
  the load-bearing error codes (190/4/10/100 + subcodes), usage headers
- Token-type selection (user/page/system-user/app) and `appsecret_proof`
- Minimal-permission discipline: every extra scope is App Review surface
- Webhook handshake + `X-Hub-Signature-256` validation

A reminder hook nudges toward `/meta-api:check` when a prompt mentions
Facebook, Instagram, WhatsApp, Messenger, or the Graph/Marketing API.

## Pairs well with

- **api-docs-first** — the generic docs-before-code discipline; meta-api is its
  Meta-specialized sibling
- **security** — webhook signature validation and token handling overlap
