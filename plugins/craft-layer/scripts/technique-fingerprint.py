#!/usr/bin/env python3
"""technique-fingerprint.py — name a reference site's stack and motion techniques.

design-research used to describe a reference's motion from a still, which for a
WebGL or scroll-driven page is a blank frame or one static state. This fetches the
homepage plus capped first-party JS and CSS and greps them for library signatures,
so a research row can say "GSAP + ScrollTrigger + Lenis" instead of guessing.

Ported from the design-corpus detector
(rationale/2026-09-25-design-capability-corpus/tools/detect.py): the signature
table, the manifest-mention guard, the first-party asset rule, and the rule that
View Transitions and CSS scroll-driven animation count only from markup or CSS.
Fonts, colour flags and hosting are corpus statistics and were not ported.

Usage:
    technique-fingerprint.py URL [--json] [--max-js N] [--max-css N] [--max-bytes N]
    technique-fingerprint.py --file PAGE.html [--base-url URL] [--json] [...]

--file reads a saved page instead of fetching. Each asset URL the page names is
resolved by its PATH under the page's directory (the host is ignored, and a path
escaping that directory is refused), so a saved "page + assets" folder works
offline. Pass --base-url with the page's real address when the saved HTML holds
absolute asset URLs, so the first-party rule sees the right host.

Exit codes:
    0  a report was produced from a readable homepage
    1  the homepage was refused, unreachable, a bot challenge or a near-empty
       shell — the report still prints and names why; record it, do not guess
    2  usage error, or a --file that cannot be read

LIMITATION: a match is positive evidence; no match is NOT evidence of absence
(lazy chunks past the cap, server-rendered markup with no client bundle, bot
walls, a library bundled under a minified name). It reads source text, never
behaviour: whether the motion honours reduced motion is visible only in a
browser, which is why the research method also asks for a reduced-motion capture
and a short scroll clip.
"""
import argparse
import json
import os
import re
import sys
import time
import zlib
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import unquote, urljoin, urlparse
from urllib.request import Request, urlopen

UA = ('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36')
MAX_JS, MAX_CSS = 24, 6
MAX_HOME, MAX_FILE, MAX_TOTAL = 8_000_000, 4_000_000, 20_000_000
TIME_BUDGET = 90  # seconds across every asset fetch, so a slow CDN cannot hang research
LIMITS = ('A match is evidence; no match is NOT absence (lazy chunks past the cap, '
          'server-only markup, bot walls, minified names). Source text is not behaviour: '
          'watch the page run for motion and its reduced-motion path.')

SIG_GROUPS = {
    'framework / rendering': {
        'Next.js': r'/_next/static|__NEXT_DATA__|self\.__next_f',
        'Nuxt': r'/_nuxt/|__NUXT__',
        'Astro': r'astro-island|/_astro/|data-astro-cid',
        'SvelteKit': r'/_app/immutable|__sveltekit',
        'Remix/React Router': r'__remixContext|__reactRouterContext|__remixManifest',
        'Gatsby': r'___gatsby',
        'Angular': r'ng-version=',
        'Vue': r'__vue_app__|data-v-[0-9a-f]{8}|vue\.runtime|__VUE_',
        'React': r'__SECRET_INTERNALS_DO_NOT_USE|__CLIENT_INTERNALS_DO_NOT_USE|_reactRootContainer|react-dom\.production|__reactContainer|react\.transitional\.element',
        'Svelte': r'\bsvelte-[a-z0-9]{6}\b',
        'SolidJS': r'_\$HY\b',
        'Qwik': r'q:container|qwikloader',
        'htmx': r'\bhx-(get|post|boost|target|swap)=|htmx\.min\.js|htmx\.org',
        'Alpine.js': r'\bx-data=|alpinejs|Alpine\.start',
        'Livewire': r'wire:(snapshot|model|click|id)|livewire\.js|window\.Livewire|livewire/livewire',
        'Inertia': r'data-page="\{(&quot;|")component|data-page=\'\{"component|data-page="app"|/inertia-[A-Za-z0-9_-]{6,}\.js|@inertiajs',
        'Hotwire/Turbo': r'data-turbo|<turbo-frame|@hotwired',
    },
    'builder / CMS': {
        'WordPress': r'/wp-content/|/wp-includes/',
        'Webflow': r'data-wf-site|data-wf-page|webflow\.js|website-files\.com',
        'Framer (site builder)': r'framerusercontent\.com|data-framer-name|framer-body',
        'Wix': r'static\.wixstatic\.com|wix-bolt|wixCIDX',
        'Squarespace': r'static1\.squarespace\.com|squarespace-cdn',
        'HubSpot CMS': r'hs_cos_wrapper|/hubfs/',
        'Ghost': r'content="Ghost|ghost-portal|ghost-sdk',
        'Shopify storefront': r'cdn\.shopify\.com|Shopify\.theme',
        'Sanity': r'cdn\.sanity\.io',
        'Contentful': r'ctfassets\.net',
        'Storyblok': r'a\.storyblok\.com',
        'Prismic': r'images\.prismic\.io',
        'DatoCMS': r'datocms-assets\.com',
        'Builder.io': r'cdn\.builder\.io',
    },
    'styling / UI system': {
        'Tailwind': r'--tw-(ring|shadow|translate|rotate|scale|gradient|border-spacing|space|blur|backdrop)|tailwindcss v\d',
        'shadcn/ui (likely)': r'data-slot="(card-header|card-title|card-content|sidebar|sidebar-menu|navigation-menu|dropdown-menu-trigger|accordion-trigger|sheet-content|dialog-content|tabs-list|select-trigger|button|badge|separator|input)"|(?<=[;{(\s])--muted-foreground\b[\s\S]{0,4000}(?<=[;{(\s])--popover-foreground\b|(?<=[;{(\s])--popover-foreground\b[\s\S]{0,4000}(?<=[;{(\s])--muted-foreground\b',
        'Radix': r'data-radix-|id="radix-|"DismissableLayer"|"RovingFocusGroup"|"FocusScope"',
        'Base UI': r'@base-ui-components|@base-ui/react|data-base-ui',
        'Headless UI': r'id="headlessui-|headlessui-(menu|listbox|dialog|popover|combobox|tabs|disclosure|switch|radiogroup)-(button|panel|options|option|items|item|label|input)',
        'React Aria': r'react-aria-[A-Z][a-zA-Z]+|data-rac\b|@react-aria',
        'Ark UI / Zag': r'data-scope="[a-z-]+"\s+data-part=|@ark-ui|@zag-js',
        'MUI': r'\bMui[A-Z][A-Za-z]+-(root|container|paper)|@mui/|MuiButtonBase',
        'Chakra UI': r'\bchakra-(button|stack|text|heading|container)\b|--chakra-(colors|space|radii)',
        'Mantine': r'\bmantine-[A-Za-z]|--mantine-',
        'Ant Design': r'\bant-(btn|layout|menu|row|col|card|typography|dropdown)\b|--ant-',
        'PrimeReact/PrimeVue': r'\bp-component\b|primereact|primevue|data-pc-(name|section)',
        'Bootstrap': r'bootstrap(\.bundle)?(\.min)?\.(css|js)|navbar-expand-|--bs-(primary|body-bg|body-color)',
        'daisyUI': r'daisyUI|daisyui',
        'Flowbite': r'flowbite',
        'HeroUI/NextUI': r'@heroui|@nextui-org|heroui|nextui',
        'Astryx': r'@astryxdesign|astryx',
        'StyleX': r'@stylexjs|/stylex-[A-Za-z0-9_-]+\.js|stylex\.props\(|stylexStyles',
        'styled-components': r'data-styled=""|data-styled-version|class="sc-[a-zA-Z]{4,10} [a-zA-Z]{4,10}',
        'Emotion': r'data-emotion|class="[^"]{0,600}\bcss-[a-z0-9]{5,8}\b|@emotion/(react|styled)',
        'Tremor': r'\btremor-[A-Z]|@tremor/',
        'Registry motion classes': r'animate-(marquee|shiny-text|shimmer|aurora|meteor|spotlight|border-beam|rainbow|ripple|orbit|grid)\b',
    },
    'motion / 3D': {
        'Motion (Framer Motion)': r'framerAppearId|data-framer-appear-id|framer-motion|MotionConfigContext|motion\.dev/',
        'GSAP': r'\b_gsap\b|GreenSock|gsap\.(to|from|timeline|registerPlugin|core)\b|/gsap(\.min)?\.js|/gsap@',
        'GSAP ScrollTrigger': r'ScrollTrigger',
        'Lenis': r'\blenis\b|lenis-smooth|data-lenis',
        'Locomotive Scroll': r'locomotive-scroll|data-scroll-container',
        'three.js': r'__THREE__|THREE\.WebGLRenderer|/three(\.module|\.core)?(\.min)?\.js|/three@',
        'React Three Fiber': r'__r3f\b',
        'Babylon.js': r'BABYLON\.(Engine|Scene)|/babylon(\.min)?\.js|@babylonjs',
        'PixiJS': r'\bPIXI\.|pixi\.js|@pixi/',
        'OGL': r'from"ogl"|/ogl@|\bogl\.js',
        'Spline': r'@splinetool|prod\.spline\.design|spline-viewer|\.splinecode',
        'Rive': r'@rive-app|rive\.wasm|\.riv["\']|rive-canvas',
        'Lottie': r'lottie-player|dotlottie|bodymovin|lottie-web|/lottie(\.min)?\.js|lottie_light|data-animation-type="lottie"|loadAnimation\(|lottie-react|@lottiefiles',
        'Unicorn Studio': r'unicorn\.studio|UnicornStudio',
        'Paper Shaders': r'@paper-design/shaders|paper-shaders',
        'anime.js': r'animejs|/anime(\.min)?\.js',
        'Matter.js': r'Matter\.Engine|matter-js|/matter(\.min)?\.js',
        'react-spring': r'@react-spring|react-spring',
        'AutoAnimate': r'@formkit/auto-animate',
        'Barba/Swup': r'data-barba|barba(\.umd)?(\.min)?\.js|swup',
        'View Transitions API': r'view-transition-name|@view-transition|::view-transition',
        'CSS scroll-driven': r'animation-timeline:\s*(view|scroll)|scroll-timeline',
        'Swiper': r'\bswiper\b',
        'Embla Carousel': r'embla',
        'Splide': r'splide',
    },
    'data / charts / editors': {
        'Recharts': r'recharts-(wrapper|surface|layer)|recharts',
        'Chart.js': r'/chart(\.umd)?(\.min)?\.js|Chart\.register|chartjs-',
        'D3': r'd3-(selection|scale|shape|geo)\b|/d3(\.v\d)?(\.min)?\.js',
        'ECharts': r'(?<![A-Za-z])echarts\b',
        'Highcharts': r'highcharts',
        'ApexCharts': r'apexcharts',
        'AG Grid': r'ag-grid|ag-theme-',
        'Mapbox/MapLibre/Leaflet': r'mapbox-gl|maplibre|leaflet',
        'Tiptap/ProseMirror': r'tiptap|ProseMirror',
        'Lexical': r'lexical',
    },
    'small UI utilities': {
        'lucide icons': r'lucide lucide-|lucide-react|class="lucide',
        'Heroicons': r'heroicons',
        'Phosphor icons': r'phosphor-icons|@phosphor',
        'Font Awesome': r'font-?awesome|\bfa-solid\b|\bfa fa-',
        'Material Symbols': r'material-icons|material-symbols',
        'Sonner': r'data-sonner-toaster',
        'cmdk': r'cmdk-(root|input|list|item)|\[cmdk-',
        'Vaul': r'data-vaul|vaul-drawer',
    },
}
SIG = {name: rx for group in SIG_GROUPS.values() for name, rx in group.items()}
SIGC = {k: re.compile(v) for k, v in SIG.items()}
GROUP_OF = {name: g for g, group in SIG_GROUPS.items() for name in group}

MANIFEST_CTX = re.compile(r'^[\w@/.-]*["\']?\s*:\s*["\'][\^~>=]*\d')
ATTR = re.compile(r'''([a-zA-Z-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+))''')
# A page that SAYS "leaflet" does not load it. The homepage is matched as its tags
# (attributes, classes, URLs), comments and inline <script>/<style> bodies; the text
# between tags — the visible copy — is dropped, for every signature.
MARKUP = re.compile(r'<script\b[^>]*>.*?(?:</script\s*>|\Z)|<style\b[^>]*>.*?(?:</style\s*>|\Z)'
                    r'|<!--.*?(?:-->|\Z)|<[^>]*>', re.S | re.I)
BOT_WALL = re.compile(r'Just a moment\.\.\.|cf-chl-|challenge-platform|Attention Required|px-captcha|_Incapsula_')
STATIC_CDN = re.compile(r'cloudfront\.net$|amazonaws\.com$|akamaized\.net$|azureedge\.net$|b-cdn\.net$|pages\.dev$|vercel\.app$|netlify\.app$')
BUILDER_CDN = re.compile(r'framerusercontent\.com|website-files\.com|webflow|squarespace|wixstatic|cdn\.shopify\.com|hsappstatic|hubspotusercontent')
# React 19 / Next ship view-transition CSS strings in their runtime; only markup or CSS is intent.
JS_NOISE = ('View Transitions API', 'CSS scroll-driven')


def real_match(rx, text):
    """A hit inside an embedded package.json map ("lenis":"^1.1") is a mention, not a use."""
    for i, m in enumerate(rx.finditer(text)):
        if i > 40:
            return True
        if not MANIFEST_CTX.match(text[m.end():m.end() + 24]):
            return True
    return False


def base(host):
    p = host.split('.')
    if len(p) > 2 and p[-2] in ('co', 'com', 'org', 'net') and len(p[-1]) == 2:
        return '.'.join(p[-3:])
    return '.'.join(p[-2:])


def assets(html, eff, max_js, max_css):
    """First-party JS and CSS the page loads, capped; every script URL; the third-party count;
    the asset URLs too malformed to resolve, each with its error."""
    js, css, skipped = [], [], []

    def join(v):
        try:
            return urljoin(eff, v.replace('&amp;', '&'))
        except ValueError as e:
            skipped.append(f'{v[:100]} ({e})')
            return ''

    for tag in re.finditer(r'<(script|link)\b([^>]*)>', html, re.I):
        attrs = {m.group(1).lower(): m.group(2) or m.group(3) or m.group(4) or ''
                 for m in ATTR.finditer(tag.group(2))}
        if tag.group(1).lower() == 'script' and attrs.get('src'):
            src = join(attrs['src'])
            if src:
                js.append(src)
        elif tag.group(1).lower() == 'link' and attrs.get('href'):
            rel, href = attrs.get('rel', '').lower(), join(attrs['href'])
            if not href:
                continue
            if 'stylesheet' in rel or (rel == 'preload' and attrs.get('as') == 'style'):
                css.append(href)
            elif rel in ('modulepreload', 'preload') and ('.js' in href or attrs.get('as') == 'script'):
                js.append(href)
    site = base(urlparse(eff).hostname or '')
    brand = site.split('.')[0]

    def keep(u):
        h = urlparse(u).hostname or ''
        return (base(h) == site or (len(brand) > 3 and brand in h)
                or BUILDER_CDN.search(u) or STATIC_CDN.search(h))

    js, css = list(dict.fromkeys(js)), list(dict.fromkeys(css))
    fjs, fcss = [u for u in js if keep(u)], [u for u in css if keep(u)]
    return {'js': fjs[:max_js], 'css': fcss[:max_css], 'all_js': js,
            'js_listed': len(fjs), 'css_listed': len(fcss),
            'third_party': len(js) - len(fjs) + len(css) - len(fcss), 'skipped': skipped}


def _decode(raw, encoding, cap):
    enc = (encoding or '').lower()
    if 'gzip' in enc or 'deflate' in enc:
        wbits = 16 + zlib.MAX_WBITS if 'gzip' in enc else zlib.MAX_WBITS
        try:
            raw = zlib.decompressobj(wbits).decompress(raw, cap)
        except zlib.error:
            try:
                raw = zlib.decompressobj(-zlib.MAX_WBITS).decompress(raw, cap)
            except zlib.error:
                pass  # labelled compressed, sent plain: read it as it came
    return raw[:cap].decode('utf-8', 'ignore')


def _read(r, cap, deadline):
    """(bytes, late): up to cap bytes, one socket read at a time, stopping at the wall-clock
    deadline. urllib's timeout bounds each socket read, so a body dripping a byte at a time
    never trips it; each read's own timeout is shrunk to the time left where the socket is
    reachable. LIMITATION: connect and the header lines are still bounded per read only."""
    sock = getattr(getattr(getattr(r, 'fp', None), 'raw', None), '_sock', None)
    read = getattr(r, 'read1', r.read)
    chunks, n = [], 0
    while n < cap:
        left = deadline - time.monotonic()
        if left <= 0:
            return b''.join(chunks), True
        if getattr(r, 'fp', True) is None:  # http.client closes the socket once Content-Length is read
            break
        try:
            if sock is not None:
                sock.settimeout(left)
            b = read(min(65536, cap - n))
        except TimeoutError:
            return b''.join(chunks), True
        if not b:
            break
        chunks.append(b)
        n += len(b)
    return b''.join(chunks), False


def net_fetch(url, cap, timeout):
    """(status, final_url, text, note). Never raises: a failure is status 0 plus a note.
    `timeout` is a wall-clock deadline for the whole fetch; a body cut by it is returned
    with a note."""
    deadline = time.monotonic() + timeout
    try:
        scheme = urlparse(url).scheme
    except ValueError as e:
        return 0, url, '', str(e)[:120]
    if scheme not in ('http', 'https'):
        return 0, url, '', 'not an http(s) URL'
    req = Request(url, headers={'User-Agent': UA, 'Accept-Language': 'en-US,en;q=0.9',
                                'Accept-Encoding': 'gzip, deflate'})
    late_note = f'stopped at the {timeout} s fetch deadline'
    try:
        with urlopen(req, timeout=timeout) as r:
            raw, late = _read(r, cap + 1, deadline)
            return r.status, r.geturl(), _decode(raw, r.headers.get('Content-Encoding'), cap), late_note if late else ''
    except HTTPError as e:
        try:
            body = _decode(_read(e, cap + 1, deadline)[0], e.headers.get('Content-Encoding') if e.headers else '', cap)
        except Exception:
            body = ''
        return e.code, url, body, f'HTTP {e.code}'
    except (URLError, OSError, ValueError) as e:
        return 0, url, '', str(getattr(e, 'reason', e))[:120]
    except Exception as e:  # http.client protocol errors, bad chunking: fail soft, never trace
        return 0, url, '', f'{type(e).__name__}: {str(e)[:100]}'


def file_fetcher(page, home_url):
    """Serve a saved page offline. An asset is looked up by its URL PATH under the page's
    directory — relative to the base URL's own directory when it sits under it — and the
    host is ignored, so a third-party asset the first-party rule wrongly admitted would be
    READ here, which is what lets a test prove the rule keeps it out."""
    root = page.parent.resolve()
    home_dir = urlparse(home_url).path.rsplit('/', 1)[0] + '/'

    def fetch(url, cap, timeout=None):
        if url == home_url:
            path = page
        else:
            p = unquote(urlparse(url).path)
            rel = p[len(home_dir):] if p.startswith(home_dir) else p.lstrip('/')
            path = (root / rel).resolve()
            if path != root and root not in path.parents:
                return 0, url, '', 'path escapes the saved page directory'
        try:
            with open(path, 'rb') as fh:
                return 200, url, fh.read(cap).decode('utf-8', 'ignore'), ''
        except OSError:
            return 404, url, '', 'not in the saved page directory'
    return fetch


def fingerprint(url, fetch, max_js, max_css, max_total):
    code, eff, html, note = fetch(url, MAX_HOME, 25)
    r = {'url': url, 'final': eff, 'status': code, 'ok': False, 'blocked': False,
         'reason': '', 'title': '', 'read': {}, 'hits': {}, 'groups': {}, 'limits': LIMITS}
    if code != 200:
        r['reason'] = f'refused or unreachable ({note or f"HTTP {code}"})'
        return r
    if len(html) < 500:
        r['reason'] = f'near-empty or shell document ({len(html)} bytes) — client-rendered pages need a browser'
        return r
    if BOT_WALL.search(html[:20000]) and len(html) < 60000:
        r['blocked'] = True
        r['reason'] = 'a bot challenge page answered instead of the site'
        return r
    r['ok'] = True
    t = re.search(r'<title[^>]*>(.*?)</title>', html, re.S | re.I)
    r['title'] = re.sub(r'\s+', ' ', t.group(1)).strip()[:120] if t else ''

    a = assets(html, eff, max_js, max_css)
    markup = '\n'.join(m.group(0) for m in MARKUP.finditer(html))
    texts = {'h': markup + '\n' + '\n'.join(a['all_js']), 'j': '', 'c': ''}
    total, deadline, stopped = len(html), time.monotonic() + TIME_BUDGET, ''
    read, skipped = {'js': 0, 'css': 0, 'failed': 0}, list(a['skipped'])
    cap_note = f'byte cap ({max_total:,} B)'
    for kind, key, urls in (('c', 'css', a['css']), ('j', 'js', a['js'])):
        parts = []
        for u in urls:
            left = max_total - total
            if left <= 0:
                stopped = stopped or cap_note
                break
            if time.monotonic() > deadline:
                stopped = stopped or f'time budget ({TIME_BUDGET} s)'
                break
            try:
                c2, _, body, _ = fetch(u, min(MAX_FILE, left), 15)
            except ValueError as e:  # a path the filesystem refuses (%00); the net fetcher never raises
                skipped.append(f'{u[:100]} ({e})')
                continue
            if c2 == 200:
                parts.append(body)
                total += len(body)
                read[key] += 1
                if len(body) >= left:
                    stopped = stopped or cap_note
            else:
                read['failed'] += 1
        texts[kind] = '\n'.join(parts)
    r['read'] = {'homepage_bytes': len(html), 'js_read': read['js'], 'js_listed': a['js_listed'],
                 'css_read': read['css'], 'css_listed': a['css_listed'], 'failed': read['failed'],
                 'third_party_not_read': a['third_party'], 'bytes': total, 'stopped_at': stopped,
                 'skipped': skipped}

    hits = {}
    for name, rx in SIGC.items():
        where = ''.join(k for k in 'hjc' if real_match(rx, texts[k]))
        if where:
            hits[name] = where
    if 'PrimeReact/PrimeVue' in hits and hits.get('Ark UI / Zag') == 'h':
        del hits['Ark UI / Zag']  # PrimeReact 11 emits data-scope/data-part too
    for name in JS_NOISE:
        if name in hits:
            w = hits[name].replace('j', '')
            if w:
                hits[name] = w
            else:
                del hits[name]
    if 'Tailwind' not in hits and len(re.findall(
            r'class="[^"]{0,600}\b(flex|grid) [^"]{0,600}\b(px|py|gap|text|bg)-[a-z0-9]', html)) > 15:
        hits['Tailwind'] = 'h*'
    if 'Tailwind' in hits:
        v = re.search(r'tailwindcss v(\d+\.\d+(?:\.\d+)?)', texts['c'] + texts['h'])
        if v:
            r['tailwind_version'] = v.group(1)
    r['hits'] = hits
    for name in hits:
        r['groups'].setdefault(GROUP_OF[name], []).append(name)
    return r


def render(r):
    status = f"HTTP {r['status']}" if r['status'] else 'no response'
    head = f"technique fingerprint — {r['url']}  ({status}"
    head += f" → {r['final']})" if r['final'] != r['url'] else ')'
    out = [head]
    if not r['ok']:
        out.append(f"NOT READ: {r['reason']}. Record the attempt; do not describe this site's motion from memory.")
        return '\n'.join(out)
    if r['title']:
        out.append(f"title: {r['title']}")
    rd = r['read']
    line = (f"read: homepage {rd['homepage_bytes']:,} B · first-party JS {rd['js_read']} of {rd['js_listed']}"
            f" · CSS {rd['css_read']} of {rd['css_listed']} · {rd['bytes']:,} B total"
            f" · {rd['third_party_not_read']} third-party asset(s) not read")
    if rd['failed']:
        line += f" · {rd['failed']} failed"
    if rd['skipped']:
        line += f" · {len(rd['skipped'])} unusable asset URL(s) skipped"
    if rd['stopped_at']:
        line += f" · stopped at the {rd['stopped_at']}"
    out.append(line)
    if rd['skipped']:
        out.append('skipped: ' + '; '.join(rd['skipped'][:3]) + (' …' if len(rd['skipped']) > 3 else ''))
    width = max(len(g) for g in SIG_GROUPS) + 2
    for g in SIG_GROUPS:
        names = r['groups'].get(g)
        if not names:
            continue
        cells = []
        for n in names:
            label = f"{n} {r['tailwind_version']}" if n == 'Tailwind' and r.get('tailwind_version') else n
            cells.append(f"{label} [{r['hits'][n]}]")
        out.append(f"{(g + ':').ljust(width)}{' · '.join(cells)}")
    if not r['hits']:
        out.append('no signature matched')
    out.append('where: h = homepage markup and script URLs · j = first-party JS · c = first-party CSS'
               ' · h* = utility-class density')
    out.append(r['limits'])
    return '\n'.join(out)


def main(argv):
    ap = argparse.ArgumentParser(description='Name a reference site\'s stack and motion techniques.')
    ap.add_argument('url', nargs='?', help='the page to fetch (https:// is assumed when no scheme is given)')
    ap.add_argument('--file', type=Path, help='read a saved page instead of fetching')
    ap.add_argument('--base-url', default='https://saved-page.invalid/',
                    help='with --file: the address the page was saved from')
    ap.add_argument('--json', action='store_true', help='print the report as JSON')
    ap.add_argument('--max-js', type=int, default=MAX_JS, help=f'first-party scripts read (default {MAX_JS})')
    ap.add_argument('--max-css', type=int, default=MAX_CSS, help=f'first-party stylesheets read (default {MAX_CSS})')
    ap.add_argument('--max-bytes', type=int, default=MAX_TOTAL, help=f'bytes read in total (default {MAX_TOTAL:,})')
    args = ap.parse_args(argv)

    if bool(args.url) == bool(args.file):
        ap.error('give exactly one of URL or --file')
    if min(args.max_js, args.max_css, args.max_bytes) < 0:
        ap.error('caps must not be negative')
    def http_url(u, what):
        try:  # a malformed host ('http://[::1/') raises ValueError: a usage error, exit 2
            ok = urlparse(u).scheme in ('http', 'https') and bool(urlparse(u).hostname)
        except ValueError:
            ok = False
        if not ok:
            ap.error(f'{what}: not a usable http(s) URL')

    if args.file:
        if not args.file.is_file() or not os.access(args.file, os.R_OK):
            ap.error(f'--file {args.file}: not a readable file')
        home = args.base_url
        http_url(home, f'--base-url {home}')
        fetch = file_fetcher(args.file, home)
    else:
        home = args.url if '://' in args.url else 'https://' + args.url
        http_url(home, args.url)

        def fetch(u, cap, timeout):
            return net_fetch(u, cap, timeout)

    r = fingerprint(home, fetch, args.max_js, args.max_css, args.max_bytes)
    print(json.dumps(r, indent=2) if args.json else render(r))
    return 0 if r['ok'] else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
