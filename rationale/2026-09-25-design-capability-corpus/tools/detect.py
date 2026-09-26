#!/usr/bin/env python3
"""Fetch a site's homepage plus its first-party JS/CSS and grep for library signatures.

Usage: detect.py candidates.json results.jsonl [workers]
candidates.json: {"domain-or-domain/path": "CATEGORY", ...}
A match is positive evidence; no match is NOT evidence of absence (lazy chunks,
server-rendered markup with no client bundle, bot walls)."""
import json, re, subprocess, sys, os, concurrent.futures as cf
from urllib.parse import urljoin, urlparse

UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36'
MAX_JS, MAX_CSS, MAX_FILE, MAX_TOTAL = 24, 6, 4_000_000, 20_000_000

SIG = {
 # framework / rendering
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
 # builders / CMS
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
 # styling / UI systems
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
 # motion / 3D
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
 # data / charts / editors
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
 # small UI utilities
 'lucide icons': r'lucide lucide-|lucide-react|class="lucide',
 'Heroicons': r'heroicons',
 'Phosphor icons': r'phosphor-icons|@phosphor',
 'Font Awesome': r'font-?awesome|\bfa-solid\b|\bfa fa-',
 'Material Symbols': r'material-icons|material-symbols',
 'Sonner': r'data-sonner-toaster',
 'cmdk': r'cmdk-(root|input|list|item)|\[cmdk-',
 'Vaul': r'data-vaul|vaul-drawer',
}
SIGC = {k: re.compile(v) for k, v in SIG.items()}
SERIF = re.compile(r'\b(Instrument Serif|Newsreader|Fraunces|Playfair|Canela|Tiempos|GT Super|Editorial New|PP Editorial|DM Serif|Source Serif|Libre Baskerville|Cormorant|EB Garamond|Signifier|Lora|Merriweather|Recoleta|Gambarino|Crimson|[A-Za-z ]+ Serif)\b', re.I)
MONO = re.compile(r'\b(JetBrains Mono|Geist Mono|IBM Plex Mono|Berkeley Mono|Fira Code|Commit Mono|Space Mono|Roboto Mono|GT America Mono|Söhne Mono|Departure Mono|Martian Mono|[A-Za-z ]+ Mono)\b', re.I)

MANIFEST_CTX = re.compile(r'^[\w@/.-]*["\']?\s*:\s*["\'][\^~>=]*\d')

def real_match(rx, text):
    """A hit inside an embedded package.json map ("solid-js":"^1.9") is a mention, not a use."""
    for i, m in enumerate(rx.finditer(text)):
        if i > 40: return True
        if not MANIFEST_CTX.match(text[m.end():m.end() + 24]): return True
    return False

GENERIC = {'serif', 'sans-serif', 'monospace', 'system-ui', 'inherit', 'initial', 'ui-sans-serif', 'ui-monospace', 'ui-serif', 'cursive', 'emoji'}

def loaded_fonts(text):
    """Families actually loaded: @font-face declarations, Google Fonts URLs, next/font class names."""
    seen = {}
    names = re.findall(r'@font-face\s*\{[^}]*?font-family:\s*["\']?([^;"\'}]+)', text)
    names += [n.replace('+', ' ') for n in re.findall(r'fonts\.googleapis\.com/css2?\?family=([A-Za-z+]+)', text)]
    names += [n.replace('_', ' ') for n in re.findall(r"['\"]__([A-Z][A-Za-z_]+?)_[0-9a-f]{6}['\"]", text)]
    for n in names:
        n = re.sub(r'\s+(Fallback|Variable|VF|Web|Regular|Medium|Bold|Light|Semibold|Book)$', '', n.strip(), flags=re.I).strip()
        if not n or n.lower() in GENERIC or n.startswith('__') or len(n) > 40: continue
        seen[n] = seen.get(n, 0) + 1
    return [f for f, _ in sorted(seen.items(), key=lambda x: -x[1])[:4]]

def curl(url, maxsize=MAX_FILE, headers=False, timeout=20):
    args = ['curl', '-sL', '--compressed', '-A', UA, '-m', str(timeout), '--max-filesize', str(maxsize),
            '-H', 'Accept-Language: en-US,en;q=0.9', '-w', '\n__META__%{http_code} %{url_effective}']
    if headers: args += ['-D', '-']
    try:
        out = subprocess.run(args + [url], capture_output=True, timeout=timeout + 5).stdout.decode('utf-8', 'ignore')
    except Exception:
        return 0, url, '', ''
    body, _, meta = out.rpartition('\n__META__')
    code, _, eff = meta.partition(' ')
    hdr = ''
    if headers:
        # strip every header block (redirect chain) off the front
        while re.match(r'HTTP/[\d.]+ \d{3}', body):
            h, sep, rest = body.partition('\r\n\r\n')
            if not sep: break
            hdr, body = h, rest
    return int(code or 0), eff or url, body, hdr

def base(host):
    p = host.split('.')
    return '.'.join(p[-3:]) if len(p) > 2 and p[-2] in ('co', 'com', 'org', 'net') and len(p[-1]) == 2 else '.'.join(p[-2:])

STATIC_CDN = re.compile(r'cloudfront\.net$|amazonaws\.com$|akamaized\.net$|azureedge\.net$|b-cdn\.net$|pages\.dev$|vercel\.app$|netlify\.app$')
BUILDER_CDN = re.compile(r'framerusercontent\.com|website-files\.com|webflow|squarespace|wixstatic|cdn\.shopify\.com|hsappstatic|hubspotusercontent')

def assets(html, eff):
    js, css = [], []
    for tag in re.finditer(r'<(script|link)\b([^>]*)>', html, re.I):
        attrs = dict((m.group(1).lower(), m.group(3)) for m in re.finditer(r'([a-zA-Z-]+)\s*=\s*(["\'])(.*?)\2', tag.group(2)))
        if tag.group(1).lower() == 'script' and attrs.get('src'):
            js.append(urljoin(eff, attrs['src'].replace('&amp;', '&')))
        elif tag.group(1).lower() == 'link' and attrs.get('href'):
            rel, href = attrs.get('rel', '').lower(), urljoin(eff, attrs['href'].replace('&amp;', '&'))
            if 'stylesheet' in rel or (rel == 'preload' and attrs.get('as') == 'style'): css.append(href)
            elif rel in ('modulepreload', 'preload') and ('.js' in href or attrs.get('as') == 'script'): js.append(href)
    site = base(urlparse(eff).hostname or '')
    brand = site.split('.')[0]
    def keep(u):
        h = urlparse(u).hostname or ''
        return base(h) == site or (len(brand) > 3 and brand in h) or BUILDER_CDN.search(u) or STATIC_CDN.search(h)
    uniq = lambda xs: list(dict.fromkeys(xs))
    return [u for u in uniq(js) if keep(u)][:MAX_JS], [u for u in uniq(css) if keep(u)][:MAX_CSS], uniq(js)

def host_of(hdr):
    h = hdr.lower()
    for key, name in [('x-vercel-id', 'Vercel'), ('x-nf-request-id', 'Netlify'), ('fly-request-id', 'Fly.io'), ('rndr-id', 'Render'),
                      ('x-railway', 'Railway'), ('x-kinsta-cache', 'Kinsta'), ('ki-cache', 'Kinsta'), ('x-github-request-id', 'GitHub Pages'),
                      ('x-amz-cf-id', 'AWS CloudFront'), ('x-served-by: cache', 'Fastly'), ('x-wix-request-id', 'Wix'),
                      ('server: cloudflare', 'Cloudflare'), ('x-powered-by: wp engine', 'WP Engine'), ('server: framer', 'Framer'), ('x-framer', 'Framer')]:
        if key in h: return name
    m = re.search(r'^server:\s*(.+)$', h, re.M)
    return m.group(1).strip()[:30] if m else ''

def probe(item):
    key, cat = item
    code, eff, html, hdr = curl('https://' + key, maxsize=8_000_000, headers=True, timeout=25)
    r = {'site': key, 'cat': cat, 'status': code, 'final': eff}
    if code != 200 or len(html) < 500:
        r['ok'] = False
        return r
    if re.search(r'Just a moment\.\.\.|cf-chl-|challenge-platform|Attention Required|px-captcha|_Incapsula_', html[:20000]) and len(html) < 60000:
        r['ok'] = False; r['blocked'] = True
        return r
    r['ok'] = True
    t = re.search(r'<title[^>]*>(.*?)</title>', html, re.S | re.I)
    d = re.search(r'<meta[^>]+name=["\']description["\'][^>]*content=["\'](.*?)["\']', html, re.S | re.I) or \
        re.search(r'<meta[^>]+content=["\'](.*?)["\'][^>]*name=["\']description["\']', html, re.S | re.I)
    r['title'] = re.sub(r'\s+', ' ', t.group(1)).strip()[:120] if t else ''
    r['desc'] = re.sub(r'\s+', ' ', d.group(1)).strip()[:200] if d else ''
    js, css, alljs = assets(html, eff)
    texts = {'h': html + '\n' + '\n'.join(alljs), 'j': '', 'c': ''}
    total = len(html)
    for kind, urls in (('c', css), ('j', js)):
        parts = []
        for u in urls:
            if total > MAX_TOTAL: break
            c2, _, b, _ = curl(u, timeout=15)
            if c2 == 200:
                parts.append(b); total += len(b)
        texts[kind] = '\n'.join(parts)
    r['fetched'] = {'js': len(js), 'css': len(css), 'bytes': total}
    hits = {}
    for name, rx in SIGC.items():
        where = ''.join(k for k in 'hjc' if real_match(rx, texts[k]))
        if where: hits[name] = where
    if 'PrimeReact/PrimeVue' in hits and hits.get('Ark UI / Zag') == 'h':
        del hits['Ark UI / Zag']  # PrimeReact 11 emits data-scope/data-part too
    for jsnoise in ('View Transitions API', 'CSS scroll-driven'):
        # React 19 / Next ship view-transition CSS strings in their runtime; only markup or CSS is intent
        if jsnoise in hits:
            w = hits[jsnoise].replace('j', '')
            if w: hits[jsnoise] = w
            else: del hits[jsnoise]
    # Tailwind utility-class density in markup as a second Tailwind signal
    if 'Tailwind' not in hits and len(re.findall(r'class="[^"]{0,600}\b(flex|grid) [^"]{0,600}\b(px|py|gap|text|bg)-[a-z0-9]', html)) > 15:
        hits['Tailwind'] = 'h*'
    if 'Tailwind' in hits:
        v = re.search(r'tailwindcss v(\d+\.\d+(?:\.\d+)?)', texts['c'] + texts['h'])
        if v: r['tailwind_version'] = v.group(1)
    r['hits'] = hits
    ft = texts['h'] + texts['c']
    r['fonts'] = loaded_fonts(ft)
    fontstr = ' | '.join(r['fonts'])
    head = html[:6000]
    htmltag = re.search(r'<html[^>]*>', head, re.I)
    dark = bool(htmltag and re.search(r'class="[^"]{0,600}\bdark\b|color-scheme:\s*dark|data-theme="dark"', htmltag.group(0))) or \
           bool(re.search(r'<body[^>]*class="[^"]{0,600}\b(bg-black|bg-(zinc|neutral|gray|slate|stone)-9[05]0|bg-\[#0)', html[:20000]))
    mc = re.search(r'<meta[^>]+name=["\']theme-color["\'][^>]*content=["\']#([0-9a-fA-F]{6})', head)
    if mc:
        rgb = [int(mc.group(1)[i:i+2], 16) for i in (0, 2, 4)]
        if sum(rgb) / 3 < 50: dark = True
    r['style'] = {
        'dark': dark,
        'serif': bool(SERIF.search(fontstr)),
        'mono': bool(MONO.search(fontstr)),
        'glass': bool(re.search(r'backdrop-filter\s*:\s*(var|blur)|class="[^"]{0,600}backdrop-blur', ft)),
        'gradient_text': bool(re.search(r'bg-clip-text|background-clip:\s*text', ft)),
        'bento': len(re.findall(r'\b(col|row)-span-\d', html)) >= 4,
        'marquee': bool(re.search(r'marquee|animate-scroll|infinite-scroll|rfm-', ft)),
        'video': '<video' in html,
        'canvas': '<canvas' in html,
    }
    r['host'] = host_of(hdr)
    cookie = hdr.lower()
    if 'laravel_session' in cookie or 'xsrf-token' in cookie: r['hits']['Laravel (cookie)'] = 'H'
    r['powered_by'] = (re.search(r'^x-powered-by:\s*(.+)$', cookie, re.M) or [None, ''])[1].strip()[:30]
    return r

if __name__ == '__main__':
    cands = json.load(open(sys.argv[1]))
    out = sys.argv[2]
    done = set()
    if os.path.exists(out):
        done = {json.loads(l)['site'] for l in open(out)}
    todo = [(k, v) for k, v in cands.items() if k not in done]
    with open(out, 'a') as f, cf.ProcessPoolExecutor(int(sys.argv[3]) if len(sys.argv) > 3 else 24) as ex:
        for i, fut in enumerate(cf.as_completed([ex.submit(probe, t) for t in todo]), 1):
            r = fut.result()
            f.write(json.dumps(r) + '\n'); f.flush()
            if i % 50 == 0: print(i, '/', len(todo), flush=True)
