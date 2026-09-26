#!/usr/bin/env python3
"""Turn detect.py output + idea shards into the tracked corpus files.

build.py <results.jsonl> <ideas_dir> <out_dir> <repo_root>"""
import json, re, sys, glob, os, hashlib, collections

RES, IDEAS, OUT, REPO = sys.argv[1:5]

CAT = {
 'CRM': 'CRM & sales', 'HOST': 'Cloud hosting & PaaS', 'DEV': 'Developer tools & APIs', 'DATA': 'Databases, data & internal tools',
 'OBS': 'Observability & incident response', 'SEC': 'Auth & security', 'PROD': 'Productivity & collaboration',
 'DESIGN': 'Design & creative tools', 'UILIB': 'UI libraries & design systems', 'REGISTRY': 'shadcn registries',
 'AI': 'AI products & LLM tooling', 'FIN': 'Fintech, billing & payroll', 'ANALYTICS': 'Product analytics & experimentation',
 'MKT': 'Marketing, email & creator tools', 'SUPPORT': 'Support, feedback & onboarding', 'HR': 'HR & recruiting',
 'COMM': 'E-commerce operations', 'CMS': 'CMS & site builders', 'SCHED': 'Scheduling, forms & e-sign',
 'LARAVEL': 'Laravel & PHP ecosystem', 'OSS': 'Open-source apps', 'VERT': 'Vertical SaaS (health, edu, property, legal, logistics)',
 'FW': 'Framework & motion-library sites', 'STUDIO': 'Motion-forward studios (capability ceiling)', 'CONSUMER': 'Consumer web apps',
 'GALLERY': 'Gallery picks (MUI/Tailwind showcases, design galleries)',
}
ORDER = ['CRM', 'HOST', 'LARAVEL', 'DEV', 'DATA', 'OBS', 'SEC', 'AI', 'PROD', 'SUPPORT', 'MKT', 'ANALYTICS', 'FIN', 'HR', 'COMM',
         'SCHED', 'VERT', 'CMS', 'OSS', 'DESIGN', 'UILIB', 'REGISTRY', 'FW', 'STUDIO', 'CONSUMER', 'GALLERY']

FRAMEWORK = ['Next.js', 'Nuxt', 'Astro', 'SvelteKit', 'Remix/React Router', 'Gatsby', 'Angular', 'Inertia', 'Livewire', 'Alpine.js',
             'htmx', 'Hotwire/Turbo', 'Qwik', 'SolidJS', 'Vue', 'React', 'Svelte']
BUILDER = ['Framer (site builder)', 'Webflow', 'WordPress', 'Wix', 'Squarespace', 'HubSpot CMS', 'Ghost', 'Shopify storefront']
CMSES = ['Sanity', 'Contentful', 'Storyblok', 'Prismic', 'DatoCMS', 'Builder.io']
UI = ['shadcn/ui (likely)', 'Radix', 'Base UI', 'Headless UI', 'React Aria', 'Ark UI / Zag', 'MUI', 'Chakra UI', 'Mantine', 'Ant Design',
      'PrimeReact/PrimeVue', 'HeroUI/NextUI', 'daisyUI', 'Flowbite', 'Bootstrap', 'Tremor', 'Astryx', 'StyleX', 'Tailwind',
      'styled-components', 'Emotion', 'Registry motion classes']
MOTION = ['three.js', 'React Three Fiber', 'Babylon.js', 'PixiJS', 'OGL', 'Spline', 'Unicorn Studio', 'Paper Shaders', 'GSAP',
          'GSAP ScrollTrigger', 'Lenis', 'Locomotive Scroll', 'Motion (Framer Motion)', 'Rive', 'Lottie', 'anime.js', 'react-spring',
          'Matter.js', 'AutoAnimate', 'Barba/Swup', 'View Transitions API', 'CSS scroll-driven']
OTHER = ['Recharts', 'Chart.js', 'D3', 'ECharts', 'Highcharts', 'ApexCharts', 'AG Grid', 'Mapbox/MapLibre/Leaflet', 'Tiptap/ProseMirror',
         'Lexical', 'cmdk', 'Sonner', 'Vaul', 'Swiper', 'Embla Carousel', 'Splide', 'lucide icons', 'Heroicons', 'Phosphor icons',
         'Font Awesome', 'Material Symbols']
SHORT = {'shadcn/ui (likely)': 'shadcn/ui*', 'Motion (Framer Motion)': 'Motion', 'Framer (site builder)': 'Framer site',
         'Registry motion classes': 'registry-motion*', 'GSAP ScrollTrigger': 'ScrollTrigger', 'PrimeReact/PrimeVue': 'Prime',
         'Remix/React Router': 'React Router', 'Mapbox/MapLibre/Leaflet': 'maps', 'Tiptap/ProseMirror': 'Tiptap',
         'View Transitions API': 'View Transitions', 'CSS scroll-driven': 'CSS scroll-driven', 'lucide icons': 'lucide',
         'Laravel (cookie)': 'Laravel', 'HeroUI/NextUI': 'HeroUI', 'Ark UI / Zag': 'Ark/Zag', 'React Three Fiber': 'R3F'}
THREE_D = {'three.js', 'React Three Fiber', 'Babylon.js', 'PixiJS', 'OGL', 'Spline', 'Unicorn Studio', 'Paper Shaders'}
SCROLL = {'GSAP ScrollTrigger', 'Lenis', 'Locomotive Scroll', 'CSS scroll-driven'}
JSMOTION = {'Motion (Framer Motion)', 'GSAP', 'Rive', 'Lottie', 'anime.js', 'react-spring', 'Matter.js', 'AutoAnimate', 'Barba/Swup',
            'View Transitions API', 'Registry motion classes'}

# grep terms used to ask "does any marketplace skill cover this?"
TERMS = {
 'Next.js': r'Next\.js', 'Nuxt': r'\bNuxt\b', 'Astro': r'\bAstro\b', 'SvelteKit': r'SvelteKit', 'Remix/React Router': r'React Router|\bRemix\b',
 'Gatsby': r'Gatsby', 'Angular': r'\bAngular\b', 'Vue': r'\bVue\b', 'React': r'\bReact\b', 'SolidJS': r'SolidJS', 'Qwik': r'\bQwik\b',
 'htmx': r'\bhtmx\b', 'Alpine.js': r'Alpine', 'Livewire': r'Livewire', 'Inertia': r'Inertia', 'Hotwire/Turbo': r'Hotwire',
 'Svelte': r'\bSvelte\b', 'WordPress': r'WordPress', 'Webflow': r'Webflow', 'Framer (site builder)': r'\bFramer\b(?! Motion)', 'Wix': r'\bWix\b',
 'Squarespace': r'Squarespace', 'HubSpot CMS': r'HubSpot', 'Ghost': r'\bGhost\b', 'Shopify storefront': r'Shopify', 'Sanity': r'\bSanity\b',
 'Contentful': r'Contentful', 'Storyblok': r'Storyblok', 'Prismic': r'Prismic', 'DatoCMS': r'DatoCMS', 'Builder.io': r'Builder\.io',
 'Tailwind': r'Tailwind', 'shadcn/ui (likely)': r'shadcn', 'Radix': r'Radix', 'Base UI': r'Base UI', 'Headless UI': r'Headless UI',
 'React Aria': r'React Aria', 'Ark UI / Zag': r'\bArk\b', 'MUI': r'\bMUI\b|Material UI', 'Chakra UI': r'Chakra', 'Mantine': r'Mantine',
 'Ant Design': r'Ant Design', 'PrimeReact/PrimeVue': r'PrimeReact|PrimeVue', 'Bootstrap': r'Bootstrap', 'daisyUI': r'daisyUI',
 'Flowbite': r'Flowbite', 'HeroUI/NextUI': r'HeroUI|NextUI', 'Astryx': r'Astryx', 'StyleX': r'StyleX', 'styled-components': r'styled-components',
 'Emotion': r'\bEmotion\b', 'Tremor': r'Tremor', 'Registry motion classes': r'Magic UI|Aceternity',
 'Motion (Framer Motion)': r'Framer Motion|framer-motion|Motion \(ex-Framer\)|motion/react', 'GSAP': r'GSAP', 'GSAP ScrollTrigger': r'ScrollTrigger',
 'Lenis': r'Lenis', 'Locomotive Scroll': r'Locomotive', 'three.js': r'Three\.js|three\.js', 'React Three Fiber': r'R3F|react-three-fiber',
 'Babylon.js': r'Babylon', 'PixiJS': r'Pixi', 'OGL': r'\bOGL\b', 'Spline': r'\bSpline\b', 'Rive': r'\bRive\b', 'Lottie': r'Lottie',
 'Unicorn Studio': r'Unicorn Studio', 'Paper Shaders': r'Paper Shaders|paper-design', 'anime.js': r'anime\.js|animejs', 'Matter.js': r'matter\.js|Matter\.js',
 'react-spring': r'react-spring', 'AutoAnimate': r'AutoAnimate|auto-animate', 'Barba/Swup': r'Barba|Swup', 'View Transitions API': r'View Transitions?',
 'CSS scroll-driven': r'scroll-driven', 'Swiper': r'Swiper', 'Embla Carousel': r'Embla', 'Splide': r'Splide', 'Recharts': r'Recharts',
 'Chart.js': r'Chart\.js', 'D3': r'\bD3\b|d3\.js', 'ECharts': r'ECharts', 'Highcharts': r'Highcharts', 'ApexCharts': r'ApexCharts',
 'AG Grid': r'AG Grid', 'Mapbox/MapLibre/Leaflet': r'Mapbox|MapLibre|Leaflet', 'Tiptap/ProseMirror': r'Tiptap|ProseMirror', 'Lexical': r'Lexical',
 'lucide icons': r'[Ll]ucide', 'Heroicons': r'Heroicons', 'Phosphor icons': r'Phosphor', 'Font Awesome': r'Font ?Awesome',
 'Material Symbols': r'Material (Symbols|Icons)', 'Sonner': r'Sonner', 'cmdk': r'\bcmdk\b', 'Vaul': r'\bVaul\b', 'Laravel (cookie)': r'Laravel',
}

def skill_texts():
    fm, body = {}, {}
    for f in glob.glob(f'{REPO}/plugins/*/skills/**/*.md', recursive=True):
        parts = f[len(REPO) + 1:].split('/')
        key = f'{parts[1]}:{parts[3]}'
        s = open(f).read()
        body[key] = body.get(key, '') + '\n' + s
        if parts[-1] == 'SKILL.md':
            m = re.match(r'---\n(.*?)\n---', s, re.S)
            fm[key] = (m.group(1) if m else '') + '\n' + key
    return fm, body

FM, BODY = skill_texts()

def coverage(tech):
    rx = re.compile(TERMS.get(tech, re.escape(tech)))
    ded = sorted(k for k, t in FM.items() if rx.search(t))
    men = sorted(k for k, t in BODY.items() if rx.search(t) and k not in ded)
    return ded, men

def cell(xs):
    return ', '.join(SHORT.get(x, x) for x in xs) or '—'

def clean(s, n):
    s = re.sub(r'&amp;', '&', s or ''); s = re.sub(r'&#0?39;|&#x27;|&apos;', "'", s); s = re.sub(r'&quot;', '"', s)
    s = re.sub(r'&[a-z#0-9]+;', ' ', s); s = re.sub(r'[|\t\n]', ' ', s).strip()
    return (s[:n - 1] + '…') if len(s) > n else s

def motion_tier(h):
    if THREE_D & h: return '3D/WebGL'
    if SCROLL & h: return 'Scroll-choreographed'
    if JSMOTION & h: return 'JS motion'
    return 'Static/CSS'

LOOKS = json.load(open(os.environ['LOOKS'])) if os.environ.get('LOOKS') else {}            # light colour-scheme pass
LOOKS_DARK = json.load(open(os.environ['LOOKS_DARK'])) if os.environ.get('LOOKS_DARK') else {}  # dark colour-scheme pass

def theme(site):
    m = LOOKS.get(site) or LOOKS_DARK.get(site)
    if not m: return ''
    lum, sat, hue, cov = m
    t = 'Dark' if lum < 0.3 else ('Mid-tone' if lum < 0.6 else 'Light')
    dk = LOOKS_DARK.get(site)
    if site in LOOKS and dk and lum >= 0.6 and lum - dk[0] >= 0.35: t = 'Light + dark (follows OS)'
    t += ', vivid' if sat > 0.12 else (', muted' if sat < 0.04 else '')
    if hue and cov >= 0.01: t += f', {hue} accent'
    return t

def look(st, h, site=''):
    t = [theme(site) or 'theme n/a']
    if st.get('serif'): t.append('serif display')
    if st.get('mono'): t.append('mono accents')
    if st.get('bento'): t.append('span grid')
    if st.get('marquee'): t.append('marquee')
    if st.get('video'): t.append('video')
    if st.get('canvas') and not (THREE_D & h): t.append('canvas')
    return ' · '.join(t)

# ---------- sites ----------
rows, seen = [], set()
status = collections.Counter()
for line in open(RES):
    r = json.loads(line)
    status['ok' if r.get('ok') else ('blocked' if r.get('blocked') else 'failed')] += 1
    if not r.get('ok'): continue
    final = re.sub(r'^https?://(www\.)?', '', r['final']).split('?')[0].rstrip('/')
    if final in seen: continue
    seen.add(final)
    cat = r['cat'].split(':')[0]
    h = r.get('hits', {})
    hs = set(h)
    fw = [x for x in FRAMEWORK if x in hs]
    if {'Next.js', 'Remix/React Router', 'Gatsby'} & hs: fw = [x for x in fw if x != 'React']
    if 'Nuxt' in hs: fw = [x for x in fw if x != 'Vue']
    if 'Inertia' in fw or 'Livewire' in fw or 'Laravel (cookie)' in hs: fw = (['Laravel'] if 'Laravel (cookie)' in hs else []) + fw
    rows.append({
        'site': r['site'], 'cat': cat, 'title': clean(r.get('title') or r.get('desc'), 60),
        'framework': fw[:4],
        'builder': [x for x in BUILDER + CMSES if x in hs],
        'ui': [x for x in UI if x in hs], 'motion': [x for x in MOTION if x in hs], 'other': [x for x in OTHER if x in hs],
        'tier': motion_tier(hs), 'look': look(r.get('style', {}), hs, r['site']), 'theme': theme(r['site']), 'fonts': r.get('fonts', [])[:2], 'host': r.get('host', ''),
        'tw': r.get('tailwind_version', ''), 'hits': h,
    })

rows.sort(key=lambda x: (ORDER.index(x['cat']) if x['cat'] in ORDER else 99, x['site']))
os.makedirs(OUT, exist_ok=True)
with open(f'{OUT}/sites.tsv', 'w') as f:
    f.write('site\tcategory\ttitle\tframework\tbuilder_cms\tui\tmotion_3d\tother_libs\tmotion_tier\tlook\tfonts\thost\ttailwind_version\n')
    for x in rows:
        f.write('\t'.join([x['site'], CAT.get(x['cat'], x['cat']), x['title'], ', '.join(x['framework']), ', '.join(x['builder']),
                           ', '.join(x['ui']), ', '.join(x['motion']), ', '.join(x['other']), x['tier'], x['look'],
                           ', '.join(x['fonts']), x['host'], x['tw']]) + '\n')

with open(f'{OUT}/sites.md', 'w') as f:
    f.write('# Design corpus — sites\n\n')
    f.write(f'{len(rows)} live sites, generated {os.environ.get("CORPUS_DATE", "")} by fetching each homepage plus its first-party JS/CSS and matching '
            'library signatures. Method, signature table and limits: `README.md`. Machine-readable copy: `sites.tsv`.\n\n')
    f.write('`*` marks an inference, not a direct package hit: `shadcn/ui*` = shadcn `data-slot` markup or its CSS-variable set; '
            '`registry-motion*` = Magic UI / Aceternity-style keyframe class names. A blank cell means **not detected**, not "not used".\n\n')
    f.write('Contents: ' + ' · '.join(f'[{CAT[c]}](#{re.sub(r"[^a-z0-9 -]", "", CAT[c].lower()).replace(" ", "-")}) ({sum(1 for x in rows if x["cat"] == c)})'
                                      for c in ORDER if any(x['cat'] == c for x in rows)) + '\n\n')
    n = 0
    for c in ORDER:
        grp = [x for x in rows if x['cat'] == c]
        if not grp: continue
        f.write(f'## {CAT[c]}\n\n| # | Site | What | Framework / builder | UI system | Motion / 3D | Other libs | Look | Host |\n|---|---|---|---|---|---|---|---|---|\n')
        for x in grp:
            n += 1
            fw = cell(x['framework'] + x['builder'])
            ui = cell(x['ui']) + (f' (v{x["tw"]})' if x['tw'] and 'Tailwind' in x['ui'] else '')
            f.write(f'| {n} | [{x["site"]}](https://{x["site"]}) | {x["title"] or "—"} | {fw} | {ui} | {cell(x["motion"])} | {cell(x["other"])} | '
                    f'{x["look"]}{" · " + "/".join(x["fonts"]) if x["fonts"] else ""} | {x["host"] or "—"} |\n')
        f.write('\n')

# ---------- prevalence + coverage ----------
N = len(rows)
prev = collections.Counter(t for x in rows for t in x['hits'])
tiers = collections.Counter(x['tier'] for x in rows)
cov = {t: coverage(t) for t in prev}

# ---------- ideas ----------
ideas = []
for p in sorted(glob.glob(f'{IDEAS}/ideas_*.tsv')):
    lines = open(p).read().rstrip('\n').split('\n')
    hdr = lines[0].split('\t')
    for l in lines[1:]:
        v = l.split('\t')
        if len(v) != len(hdr): raise SystemExit(f'{p}: bad row {l[:80]}')
        ideas.append(dict(zip(hdr, v)))

STACK_SIG = {'shadcn/ui': {'shadcn/ui (likely)'}, 'shadcn registry': {'Registry motion classes', 'shadcn/ui (likely)'},
             'Tailwind': {'Tailwind'}, 'MUI': {'MUI'}, 'PrimeReact': {'PrimeReact/PrimeVue'}, 'Astryx': {'Astryx', 'StyleX'}}
OTHER_SIG = {'Mantine': 'Mantine', 'Ant Design': 'Ant Design', 'HeroUI': 'HeroUI/NextUI', 'Chakra UI': 'Chakra UI', 'Radix Themes': 'Radix',
             'PrimeVue': 'PrimeReact/PrimeVue', 'daisyUI': 'daisyUI', 'Flowbite': 'Flowbite', 'Park UI (Ark)': 'Ark UI / Zag',
             'Vuetify': 'Vue', 'Nuxt UI': 'Nuxt', 'Element Plus': 'Vue'}
MOTION_SIG = {'Motion': {'Motion (Framer Motion)'}, 'GSAP + ScrollTrigger': {'GSAP ScrollTrigger', 'GSAP'}, 'Lenis + GSAP': {'Lenis'},
              'three.js / R3F': {'three.js', 'React Three Fiber'}, 'Spline': {'Spline'}, 'Rive': {'Rive'}, 'Lottie': {'Lottie'},
              'View Transitions API': {'View Transitions API'}, 'CSS scroll-driven': {'CSS scroll-driven'}, 'anime.js': {'anime.js'},
              'Matter.js': {'Matter.js'}, 'Paper Shaders': {'Paper Shaders'}, 'AutoAnimate': {'AutoAnimate'}}
VIZ_SIG = {'Recharts': 'Recharts', 'ECharts': 'ECharts', 'Chart.js': 'Chart.js', 'D3': 'D3', 'AG Grid': 'AG Grid', 'Tremor': 'Tremor'}

def idea_axes(i):
    """(axis label, tech name for coverage lookup) pairs an idea exercises."""
    ax = []
    s, a = i['ui_stack'], i['addon']
    if s == 'shadcn/ui': ax.append(('UI', 'shadcn/ui (likely)'))
    elif s == 'shadcn registry':
        ax.append(('UI', 'shadcn/ui (likely)'))
        ax.append(('registry', a))
    elif s == 'Tailwind':
        ax.append(('UI', 'Tailwind'))
        for k in ('Headless UI', 'Base UI', 'React Aria'):
            if k in a: ax.append(('UI', k))
    elif s == 'MUI': ax.append(('UI', 'MUI'))
    elif s == 'PrimeReact': ax.append(('UI', 'PrimeReact'))
    elif s == 'Astryx': ax.append(('UI', 'Astryx'))
    else:
        ax.append(('UI', {'HeroUI': 'HeroUI/NextUI'}.get(a, a)))
    m = i['motion_3d']
    if m != 'none':
        for t in ({'three.js / R3F': ['three.js', 'React Three Fiber'], 'GSAP + ScrollTrigger': ['GSAP', 'GSAP ScrollTrigger'],
                   'Lenis + GSAP': ['Lenis', 'GSAP']}.get(m) or [next(iter(MOTION_SIG.get(m, {m})))]):
            ax.append(('motion', t))
    v = i['data_viz']
    if v not in ('none', ''):
        ax.append(('data', {'MUI X Charts': 'MUI', 'TanStack Table': 'TanStack Table', 'visx': 'visx', 'Nivo': 'Nivo'}.get(v, v)))
    b = i['backend']
    ax.append(('backend', {'Laravel + Inertia (React)': 'Inertia', 'Laravel + Inertia (Vue)': 'Inertia', 'Next.js App Router': 'Next.js',
                           'Vite SPA + REST API': 'Vite', 'React Router (framework mode)': 'Remix/React Router', 'Astro + islands': 'Astro',
                           'Nuxt': 'Nuxt'}.get(b, b)))
    return list(dict.fromkeys(ax))

TERMS.update({'PrimeReact': r'PrimeReact|primereact', 'PrimeVue': r'PrimeVue|primevue', 'Magic UI': r'Magic UI', 'Aceternity UI': r'Aceternity', 'Vite': r'\bVite\b', 'TanStack Table': r'TanStack Table|@tanstack/react-table', 'visx': r'\bvisx\b', 'Nivo': r'\bNivo\b',
              'Origin UI': r'Origin UI', 'ReUI': r'ReUI', 'Kokonut UI': r'Kokonut', 'Animate UI': r'Animate UI', 'Motion Primitives': r'Motion Primitives',
              'Cult UI': r'Cult UI', 'shadcnblocks': r'shadcnblocks', '21st.dev': r'21st\.dev', 'tweakcn theme': r'tweakcn', 'Eldora UI': r'Eldora',
              'Skiper UI': r'Skiper', 'Smooth UI': r'Smooth UI', 'React Bits': r'React Bits', 'Vuetify': r'Vuetify', 'Element Plus': r'Element Plus',
              'Nuxt UI': r'Nuxt UI', 'Radix Themes': r'Radix Themes', 'Park UI (Ark)': r'Park UI|\bArk\b'})
covc = {}
def cv(t):
    if t not in covc: covc[t] = coverage(t)
    return covc[t]

use = collections.Counter()
def refs(i):
    want = set(STACK_SIG.get(i['ui_stack'], {OTHER_SIG.get(i['addon'], i['addon'])}))
    mw = MOTION_SIG.get(i['motion_3d'], set())
    vw = VIZ_SIG.get(i['data_viz'])
    best = []
    for x in rows:
        hs = set(x['hits'])
        sc = 3 * bool(want & hs) + 3 * bool(mw & hs) + (1 if vw and vw in hs else 0) + (1 if x['cat'] == i['category'] else 0)
        if sc < 3: continue
        sc -= 0.5 * use[x['site']]
        best.append((sc, hashlib.md5((i['id'] + x['site']).encode()).hexdigest(), x['site'], (want & hs, mw & hs)))
    best.sort(key=lambda t: (-t[0], t[1]))
    out = []
    for sc, _, site, why in best[:2]:
        use[site] += 1
        out.append(site)
    return out

gapcount = collections.Counter(); fully = 0
for i in ideas:
    ax = idea_axes(i)
    tags = []
    gaps = []
    for label, t in ax:
        ded, men = cv(t)
        own = sorted([k for k in ded if re.sub(r'[^a-z]', '', t.lower().split('/')[0].split(' (')[0])[:5] in re.sub(r'[^a-z]', '', k.split(':')[1])], key=lambda k: 'best-practices' not in k)
        if own: tags.append(f'{SHORT.get(t, t)}→{own[0]}')
        elif ded: tags.append(f'{SHORT.get(t, t)}→grouped in {ded[0]}')
        elif men: tags.append(f'{SHORT.get(t, t)}→mention only ({men[0]})'); gaps.append(f'{SHORT.get(t, t)} (mention only)')
        else: tags.append(f'{SHORT.get(t, t)}→**no skill**'); gaps.append(SHORT.get(t, t))
    i['_cov'] = '; '.join(tags); i['_gaps'] = gaps; i['_refs'] = refs(i)
    for g in gaps: gapcount[g] += 1
    if not gaps: fully += 1

with open(f'{OUT}/ideas.tsv', 'w') as f:
    cols = ['id', 'name', 'pitch', 'category', 'screens', 'ui_stack', 'addon', 'motion_3d', 'data_viz', 'backend', 'capability_focus']
    f.write('\t'.join(cols + ['reference_sites', 'skill_coverage', 'gaps']) + '\n')
    for i in ideas:
        f.write('\t'.join([i[c] for c in cols] + [', '.join(i['_refs']), i['_cov'], ', '.join(i['_gaps'])]) + '\n')

stack_counts = collections.Counter(i['ui_stack'] for i in ideas)
with open(f'{OUT}/ideas.md', 'w') as f:
    f.write('# Design corpus — 500 web-app ideas\n\n')
    f.write(f'{len(ideas)} ideas, each a buildable app shape pinned to one UI stack, one motion/3D choice, one data-viz choice and one backend. '
            'Reference sites are corpus sites whose DETECTED stack or motion library matches (scored mechanically, see `README.md`); '
            '"Gaps" names each axis no shipped skill covers ("mention only" = some skill body names it, no frontmatter does). '
            'The full per-axis skill map is the `skill_coverage` column of `ideas.tsv`.\n\n')
    f.write('Stack mix: ' + ', '.join(f'{k} {v}' for k, v in stack_counts.most_common()) + '.\n\n')
    for c in sorted({i['category'] for i in ideas}, key=lambda c: ORDER.index(c) if c in ORDER else 99):
        grp = [i for i in ideas if i['category'] == c]
        f.write(f'## {CAT.get(c, c)} ({len(grp)})\n\n| ID | Idea | Key screens | UI stack | Motion / 3D | Data | Backend | Hardest part | Reference sites | Gaps |\n|---|---|---|---|---|---|---|---|---|---|\n')
        for i in grp:
            f.write(f'| {i["id"]} | **{clean(i["name"], 40)}** — {clean(i["pitch"], 125)} | {clean(i["screens"], 90)} | {i["ui_stack"]} ({clean(i["addon"], 40)}) | '
                    f'{i["motion_3d"]} | {i["data_viz"]} | {i["backend"]} | {clean(i["capability_focus"], 115)} | '
                    f'{", ".join(i["_refs"]) or "—"} | {", ".join(i["_gaps"]) or "—"} |\n')
        f.write('\n')

json.dump({'status': status, 'N': N, 'prev': prev, 'tiers': tiers, 'cov': {k: cov[k] for k in cov},
           'ideas': len(ideas), 'fully': fully, 'gapcount': gapcount, 'stack_counts': stack_counts,
           'idea_cov': {k: v for k, v in covc.items()}, 'cats': collections.Counter(x['cat'] for x in rows)},
          open(f'{OUT}/.stats.json', 'w'), indent=1, default=list)
print('sites', N, dict(status), 'ideas', len(ideas), 'fully covered', fully)
