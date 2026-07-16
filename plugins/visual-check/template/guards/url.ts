// URL / egress guards (spec D17 — non-negotiable). Before the harness drives a
// browser at ANY target/reference URL, classify the host. A localhost / dev-host /
// `file://` target is "local" and runs freely. A PRODUCTION host, an INTERNAL
// private-network host, or a cloud METADATA endpoint is NON-LOCAL: the guard emits
// an explicit WARNING and REFUSES to proceed until the run acknowledges it
// (`--ack-egress`). This keeps a check from silently driving a live production site,
// and — the sharp edge — from letting a browser hit a cloud metadata service
// (169.254.169.254 &c.) and exfiltrate instance credentials via SSRF.
//
// Pure + dependency-free: it takes URL strings and returns a verdict. `bin/
// visual-check.mjs` wires it into the deterministic drive path. The AGENT engine's
// egress (it sends screenshots to a model) is a SEPARATE concern honored elsewhere:
// `config.allowLlmEngine: false` forbids that path (agents/visual-check-engineer.md).
//
// NOTE: classification is PARSE-TIME only — it buckets the literal host string, it does
// NOT resolve DNS. A name that parses as "production" but resolves to a private/metadata
// IP (or a DNS-rebind that flips after this check) is out of scope here; the guard is a
// guardrail against obvious footguns, not a full SSRF egress firewall.

export type UrlCategory = 'local' | 'internal' | 'metadata' | 'production';

export type UrlClassification = {
  url: string;
  role: string; // 'target' | 'reference' | …
  category: UrlCategory;
  host: string;
  local: boolean; // category === 'local'
  note: string; // human-readable explanation
};

export type EgressInput = {
  urls: Array<{ role: string; url: string }>;
  ack: boolean;
};

export type EgressResult = {
  ok: boolean;
  warnings: string[];
  reason?: string;
  classifications: UrlClassification[];
};

export const EGRESS_ACK_FLAG = '--ack-egress';

const IPV4 = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;

// Cloud instance-metadata endpoints (IMDS). A browser coaxed to one of these can
// hand back short-lived cloud credentials, so they are the most dangerous class.
const METADATA_IPS = new Set(['169.254.169.254', '100.100.100.200']);
const METADATA_HOSTS = new Set(['metadata.google.internal', 'metadata']);
const METADATA_IPV6 = new Set(['fd00:ec2::254']);

// Extract the embedded IPv4 of an IPv4-mapped IPv6 literal (`::ffff:a.b.c.d`, which
// Node's URL normalizes to the hex form `::ffff:HHHH:HHHH`). Returns the dotted-quad so
// a mapped loopback/private/metadata address reclassifies to its real v4 bucket rather
// than being mistaken for an opaque (production) IPv6 host. Non-mapped input → null.
function mappedV4(h: string): string | null {
  const m = /^::ffff:(.+)$/i.exec(h);
  if (!m) return null;
  const rest = m[1];
  if (rest.includes('.')) return IPV4.test(rest) ? rest : null;
  const parts = rest.split(':');
  if (parts.length !== 2 || !/^[0-9a-f]{1,4}$/i.test(parts[0]) || !/^[0-9a-f]{1,4}$/i.test(parts[1])) {
    return null;
  }
  const hi = parseInt(parts[0], 16);
  const lo = parseInt(parts[1], 16);
  return `${(hi >> 8) & 0xff}.${hi & 0xff}.${(lo >> 8) & 0xff}.${lo & 0xff}`;
}

function classifyHttpHost(host: string): { category: UrlCategory; note: string } {
  // `URL.hostname` returns IPv6 literals bracketed (`[::1]`); strip for matching.
  const stripped = host.toLowerCase().replace(/^\[|\]$/g, '');
  // Reclassify an IPv4-mapped IPv6 literal by its embedded v4 (loopback/private/metadata).
  const h = mappedV4(stripped) ?? stripped;

  // Loopback / dev hostnames — freely drivable. Only the BARE `localhost` is trusted;
  // a `*.localhost` label is attacker-influenceable DNS, so it is NOT auto-trusted.
  if (h === 'localhost') return { category: 'local', note: 'loopback hostname' };
  if (h === '::1' || h === '0:0:0:0:0:0:0:1') return { category: 'local', note: 'IPv6 loopback' };

  // Cloud metadata (checked before the generic link-local / private buckets).
  if (METADATA_IPS.has(h) || METADATA_HOSTS.has(h) || METADATA_IPV6.has(h)) {
    return { category: 'metadata', note: 'cloud instance-metadata endpoint' };
  }

  const m = IPV4.exec(h);
  if (m) {
    const [a, b] = [Number(m[1]), Number(m[2])];
    if (a === 127) return { category: 'local', note: 'IPv4 loopback (127.0.0.0/8)' };
    // Only the exact unspecified address 0.0.0.0 is bind-all; the rest of 0.0.0.0/8 is not.
    if (a === 0 && b === 0 && Number(m[3]) === 0 && Number(m[4]) === 0) {
      return { category: 'local', note: 'unspecified/bind-all address' };
    }
    if (a === 10) return { category: 'internal', note: 'private network (10.0.0.0/8)' };
    if (a === 172 && b >= 16 && b <= 31) return { category: 'internal', note: 'private network (172.16.0.0/12)' };
    if (a === 192 && b === 168) return { category: 'internal', note: 'private network (192.168.0.0/16)' };
    if (a === 169 && b === 254) return { category: 'internal', note: 'link-local (169.254.0.0/16)' };
    return { category: 'production', note: 'public IPv4 address' };
  }

  // IPv6 unique-local (fc00::/7) and link-local (fe80::/10) are internal networks.
  if (/^f[cd][0-9a-f]*:/.test(h)) return { category: 'internal', note: 'IPv6 unique-local (fc00::/7)' };
  if (/^fe[89ab][0-9a-f]*:/.test(h)) return { category: 'internal', note: 'IPv6 link-local (fe80::/10)' };

  // Internal DNS suffixes (mDNS `.local`, corp `.internal`).
  if (h.endsWith('.internal') || h.endsWith('.local')) return { category: 'internal', note: 'internal DNS suffix' };

  // Anything else that resolves to a public DNS name is production.
  return { category: 'production', note: 'public hostname' };
}

/** Classify one URL. `file:`/`data:`/`about:` are local; http(s) hosts are bucketed
 * by `classifyHttpHost`; an unparseable URL is treated as non-local (production) —
 * fail safe, never silently drive an unknown target. */
export function classifyUrl(url: string, role = 'target'): UrlClassification {
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return { url, role, category: 'production', host: '', local: false, note: 'unparseable URL (treated as non-local)' };
  }
  const proto = parsed.protocol.toLowerCase();
  if (proto === 'file:' || proto === 'data:' || proto === 'about:') {
    return { url, role, category: 'local', host: parsed.host, local: true, note: `${proto} resource` };
  }
  const { category, note } = classifyHttpHost(parsed.hostname);
  return { url, role, category, host: parsed.hostname, local: category === 'local', note };
}

function warningFor(c: UrlClassification): string {
  const where = `${c.role} ${c.url} (${c.host})`;
  if (c.category === 'metadata') {
    return (
      `visual-check: ${where} is a CLOUD METADATA endpoint — ${c.note}. Driving a browser at a ` +
      `metadata service can exfiltrate instance credentials (SSRF). This is HARD-BLOCKED and ` +
      `CANNOT be overridden with ${EGRESS_ACK_FLAG}.`
    );
  }
  if (c.category === 'internal') {
    return `visual-check: ${where} is an INTERNAL/private-network host — ${c.note}. This is not a local dev target.`;
  }
  return (
    `visual-check: ${where} is a PRODUCTION/non-local host — ${c.note}. Driving a real browser here ` +
    `is not read-only-safe against a live site.`
  );
}

/** Evaluate the egress guard over every URL. All-local → `ok:true`, no warnings.
 * A cloud-METADATA host is HARD-BLOCKED: it can never be acknowledged (`--ack-egress`
 * does not apply), since driving a browser at an IMDS endpoint can exfiltrate cloud
 * credentials (SSRF). Any other non-local host (production/internal) → refuse (caller
 * exits 2) unless `ack` is set, in which case the run proceeds with warnings still shown. */
export function evaluateEgressGuard(input: EgressInput): EgressResult {
  const classifications = input.urls.map((u) => classifyUrl(u.url, u.role));
  const nonLocal = classifications.filter((c) => !c.local);
  if (nonLocal.length === 0) return { ok: true, warnings: [], classifications };

  const warnings = nonLocal.map(warningFor);

  // Cloud-metadata is NEVER ackable — hard-block regardless of `--ack-egress`.
  const metadata = nonLocal.filter((c) => c.category === 'metadata');
  if (metadata.length > 0) {
    const list = metadata.map((c) => `${c.role}=${c.url}`).join(', ');
    return {
      ok: false,
      warnings,
      reason: `cloud-metadata target(s) are HARD-BLOCKED (${list}); ${EGRESS_ACK_FLAG} cannot acknowledge a metadata endpoint (SSRF risk).`,
      classifications,
    };
  }

  if (input.ack) return { ok: true, warnings, classifications };

  const list = nonLocal.map((c) => `${c.role}=${c.url}`).join(', ');
  return {
    ok: false,
    warnings,
    reason: `non-local target(s) require acknowledgement (${list}); re-run with ${EGRESS_ACK_FLAG} to proceed.`,
    classifications,
  };
}
