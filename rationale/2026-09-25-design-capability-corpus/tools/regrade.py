"""Deterministic re-grade of kept eval traces: rebuild the FINAL content of every file the
run wrote (Write = replace, Edit = old->new), then apply regex criteria per case."""
import json,re,sys,glob
def final_files(trace):
    files={}
    for l in open(trace):
        try: o=json.loads(l)
        except: continue
        def walk(x):
            if isinstance(x,dict):
                if x.get('type')=='tool_use' and x.get('name') in ('Write','Edit') and isinstance(x.get('input'),dict):
                    i=x['input']; p=i.get('file_path','')
                    if x['name']=='Write': files[p]=i.get('content','')
                    else:
                        cur=files.get(p,'')
                        if i.get('replace_all'): files[p]=cur.replace(i.get('old_string',''),i.get('new_string',''))
                        else: files[p]=cur.replace(i.get('old_string',''),i.get('new_string',''),1)
                for v in x.values(): walk(v)
            elif isinstance(x,list):
                for v in x: walk(v)
        walk(o)
    return files
def cat(files,pat=None): return '\n'.join(v for k,v in files.items() if not pat or re.search(pat,k))
C={
'primereact-v11-screen': {
  'v11': lambda f: not re.search(r"primereact/(dropdown|column|resources)|primereact\.min\.css|primeflex|<Dropdown\b",cat(f)) and bool(re.search(r"Select",cat(f))) and bool(re.search(r"@primeuix/themes",cat(f))),
  'licence': lambda f: bool(re.search(r"licen[sc]e",cat(f),re.I))},
'marquee-carousel-pause': {
  'marquee-pause-btn': lambda f: bool(re.search(r"<button[\s\S]{0,400}?(Pause|pause|Play|aria-pressed)",cat(f,'Marquee'))),
  'carousel-pause-btn': lambda f: (bool(re.search(r"<button|role=\"button\"",cat(f,'Carousel'))) and bool(re.search(r"aria-label=\{?[^>]{0,80}(pause|play|stop)|>\s*\{?[^<]{0,40}(Pause|Play|Stop)|PauseIcon|aria-pressed",cat(f,'Carousel'),re.I))) or not re.search(r"setInterval|setTimeout|autoplay",cat(f,'Carousel'),re.I),
  'dup-hidden': lambda f: (not re.search(r"duplicate|\[\.\.\.logos, \.\.\.logos\]|concat\(|\{\[0, 1\]|Array\.from\(\{ ?length: 2",cat(f,'Marquee'))) or bool(re.search(r"aria-hidden",cat(f,'Marquee')))},
'spline-hero-arrival': {
  'deferred': lambda f: bool(re.search(r"next/dynamic|import\(\s*['\"]@splinetool|lazy\(",cat(f))),
  'poster': lambda f: bool(re.search(r"poster|<img|<Image|\.webp|\.png|\.jpg|\.avif",cat(f),re.I)),
  'reduced': lambda f: bool(re.search(r"prefers-reduced-motion|useReducedMotion|reducedMotion",cat(f)))},
'astro-removed-apis': {
  'no-removed': lambda f: not re.search(r"Astro\.glob\(|ViewTransitions",cat(f)) and not any(re.search(r"src/content/config\.(ts|js|mjs)$",k) for k in f) and bool(re.search(r"loader\s*:",cat(f,'content\\.config'))),
  'zod-email': lambda f: not re.search(r"z\.string\(\)\s*\.email\(",cat(f))},
'tiptap-next-ssr': {
  'ssr-safe': lambda f: bool(re.search(r"['\"]use client['\"]",cat(f,'editor'))) and bool(re.search(r"immediatelyRender:\s*false|ssr:\s*false",cat(f))),
  'html-safe': lambda f: not re.search(r"dangerouslySetInnerHTML",cat(f)) or bool(re.search(r"DOMPurify|sanitize|sanitizeHtml|isomorphic-dompurify|generateHTML",cat(f)))},
}
for jf in sorted(glob.glob('*-r3.json')):
    d=json.load(open(jf)); case=d['cases'][0]['name']; crit=C[case]
    print('==',case)
    for arm,runs in d['cases'][0]['arms'].items():
        res={k:'' for k in crit}
        for r in runs:
            try: f=final_files(r['tracePath'])
            except Exception as e: f={}
            for k,fn in crit.items(): res[k]+= 'P' if (f and fn(f)) else ('F' if f else '?')
        print(f'  {arm:8}',res)
