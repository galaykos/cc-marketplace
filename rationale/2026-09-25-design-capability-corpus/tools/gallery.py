#!/usr/bin/env python3
"""Write shots/index.html: every screenshot as a card with its detected stack, filterable.
gallery.py results.jsonl shots_dir"""
import json, sys, os, html
RES, DIR = sys.argv[1:3]
CAT = {'CRM': 'CRM & sales', 'HOST': 'Cloud hosting & PaaS', 'LARAVEL': 'Laravel & PHP', 'DEV': 'Developer tools', 'DATA': 'Data & internal tools',
       'OBS': 'Observability', 'SEC': 'Auth & security', 'AI': 'AI products', 'PROD': 'Productivity', 'SUPPORT': 'Support & onboarding',
       'MKT': 'Marketing & creator', 'ANALYTICS': 'Analytics', 'FIN': 'Fintech & billing', 'HR': 'HR & recruiting', 'COMM': 'E-commerce ops',
       'SCHED': 'Scheduling & e-sign', 'VERT': 'Vertical SaaS', 'CMS': 'CMS & builders', 'OSS': 'Open-source apps', 'DESIGN': 'Design tools',
       'UILIB': 'UI libraries', 'REGISTRY': 'shadcn registries', 'FW': 'Framework/motion lib sites', 'STUDIO': 'Motion studios',
       'CONSUMER': 'Consumer apps', 'GALLERY': 'Gallery picks'}
SKIP = {'React', 'Vue', 'lucide icons', 'Heroicons', 'Font Awesome', 'Material Symbols', 'Phosphor icons', 'Laravel (cookie)', 'Emotion'}
cards, techs = [], {}
for l in open(RES):
    r = json.loads(l)
    if not r.get('ok'): continue
    fn = r['site'].replace('/', '_') + '.png'
    have = {m: os.path.exists(os.path.join(DIR, m, fn)) for m in ('light', 'dark')}
    if not any(have.values()): continue
    cat = r['cat'].split(':')[0]
    hits = [h for h in r.get('hits', {}) if h not in SKIP]
    for h in hits: techs[h] = techs.get(h, 0) + 1
    cards.append((cat, r['site'], hits, have, fn, r.get('title', '')))
order = list(CAT)
cards.sort(key=lambda c: (order.index(c[0]) if c[0] in order else 99, c[1]))
chips = sorted(techs, key=lambda t: -techs[t])
out = ['''<!doctype html><html><head><meta charset="utf-8"><title>Design corpus — screenshots</title><style>
:root{color-scheme:light dark;font:14px/1.4 system-ui,sans-serif}body{margin:0;background:Canvas;color:CanvasText}
header{position:sticky;top:0;z-index:2;background:Canvas;border-bottom:1px solid #8884;padding:10px 16px;display:flex;flex-wrap:wrap;gap:8px;align-items:center}
input,select,button{font:inherit;padding:4px 8px}#chips{display:flex;flex-wrap:wrap;gap:4px;max-height:66px;overflow:auto;flex-basis:100%}
.chip{border:1px solid #8886;border-radius:99px;padding:1px 8px;cursor:pointer;font-size:12px;background:none;color:inherit}.chip[aria-pressed=true]{background:#2563eb;color:#fff;border-color:#2563eb}
main{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:14px;padding:16px}
.card{border:1px solid #8884;border-radius:10px;overflow:hidden}.card img{width:100%;aspect-ratio:16/10;object-fit:cover;object-position:top;display:block;background:#8882}
.meta{padding:8px 10px}.meta a{font-weight:600;color:inherit}.cat{font-size:11px;opacity:.65}.tags{font-size:11px;opacity:.85;margin-top:3px}
#count{opacity:.7}</style></head><body><header>
<input id="q" type="search" placeholder="Filter by site or title" aria-label="Filter by site or title">
<select id="cat" aria-label="Category"><option value="">All categories</option>''']
out += [f'<option value="{c}">{html.escape(CAT[c])}</option>' for c in order if any(x[0] == c for x in cards)]
out.append('</select><label><input type="checkbox" id="dark"> Dark-preference screenshots</label><span id="count"></span><div id="chips">')
out += [f'<button class="chip" aria-pressed="false" data-t="{html.escape(t)}">{html.escape(t)} {techs[t]}</button>' for t in chips]
out.append('</div></header><main id="grid">')
for cat, site, hits, have, fn, title in cards:
    src = f'light/{fn}' if have['light'] else f'dark/{fn}'
    alt = f'dark/{fn}' if have['dark'] else src
    out.append(f'<article class="card" data-cat="{cat}" data-t="{html.escape("|".join(hits))}" data-s="{html.escape((site + " " + title).lower())}">'
               f'<a href="https://{html.escape(site)}" target="_blank" rel="noopener"><img loading="lazy" src="{src}" data-light="{src}" data-dark="{alt}" alt="{html.escape(site)} homepage"></a>'
               f'<div class="meta"><a href="https://{html.escape(site)}" target="_blank" rel="noopener">{html.escape(site)}</a> <span class="cat">{html.escape(CAT.get(cat, cat))}</span>'
               f'<div class="tags">{html.escape(", ".join(hits)) or "no library detected"}</div></div></article>')
out.append('''</main><script>
const q=document.getElementById('q'),cat=document.getElementById('cat'),dark=document.getElementById('dark'),cards=[...document.querySelectorAll('.card')],count=document.getElementById('count');
const on=new Set();
function apply(){const s=q.value.toLowerCase();let n=0;for(const c of cards){const t=c.dataset.t.split('|');const ok=(!s||c.dataset.s.includes(s))&&(!cat.value||c.dataset.cat===cat.value)&&[...on].every(x=>t.includes(x));c.hidden=!ok;if(ok)n++}count.textContent=n+' sites'}
document.getElementById('chips').addEventListener('click',e=>{const b=e.target.closest('.chip');if(!b)return;const t=b.dataset.t;on.has(t)?on.delete(t):on.add(t);b.setAttribute('aria-pressed',on.has(t));apply()});
q.addEventListener('input',apply);cat.addEventListener('change',apply);
dark.addEventListener('change',()=>{for(const i of document.querySelectorAll('img[data-dark]'))i.src=dark.checked?i.dataset.dark:i.dataset.light});apply();
</script></body></html>''')
open(os.path.join(DIR, 'index.html'), 'w').write('\n'.join(out))
print(len(cards), 'cards')
