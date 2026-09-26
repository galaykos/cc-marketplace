#!/usr/bin/env python3
"""Headless-Chrome screenshot (1280x800, first paint after load, 25 s cap) of every live site;
measure rendered luminance, colourfulness and accent hue. shots.py results.jsonl shots_dir out.json"""
import json, subprocess, os, signal, time, tempfile, colorsys, sys, concurrent.futures as cf
from PIL import Image
CH = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
RES, DIR, OUT = sys.argv[1:4]
SCHEME = {"dark": 0, "light": 1}[sys.argv[4] if len(sys.argv) > 4 else "light"]  # headless Chrome defaults to dark
os.makedirs(DIR, exist_ok=True)
HUES = [(15, 'red'), (45, 'orange'), (70, 'yellow'), (160, 'green'), (200, 'teal'), (250, 'blue'), (290, 'violet'), (335, 'pink'), (360, 'red')]

def measure(fn):
    im = Image.open(fn).convert('RGB').resize((160, 100))
    px = list(im.getdata())
    lum = sum(0.2126 * r + 0.7152 * g + 0.0722 * b for r, g, b in px) / len(px) / 255
    sat, hues = 0.0, []
    for r, g, b in px:
        h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        sat += s * v
        if s > 0.45 and v > 0.35: hues.append(h * 360)
    hue = ''
    if len(hues) > len(px) * 0.01:
        bins = {}
        for h in hues:
            name = next(n for lim, n in HUES if h <= lim)
            bins[name] = bins.get(name, 0) + 1
        hue = max(bins, key=bins.get)
    return round(lum, 3), round(sat / len(px), 3), hue, round(len(hues) / len(px), 3)

def shot(site):
    fn = os.path.join(DIR, site.replace('/', '_') + '.png')
    if not os.path.exists(fn):
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as ud:
            p = subprocess.Popen([CH, '--headless=new', '--disable-gpu', '--hide-scrollbars', '--mute-audio', f'--user-data-dir={ud}',
                                  '--window-size=1280,800', '--timeout=12000', f'--blink-settings=preferredColorScheme={SCHEME}', f'--screenshot={fn}', 'https://' + site],
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            # Chrome often idles after writing the PNG; stop once the file is written and stable
            size, deadline = -1, time.time() + 25
            while time.time() < deadline and p.poll() is None:
                time.sleep(0.5)
                if os.path.exists(fn) and os.path.getsize(fn) == size and size > 0: break
                size = os.path.getsize(fn) if os.path.exists(fn) else -1
            try: os.killpg(p.pid, signal.SIGKILL)
            except Exception: pass
    if not os.path.exists(fn) or os.path.getsize(fn) < 2000: return site, None
    time.sleep(0.2)
    try: return site, measure(fn)
    except Exception: return site, None

if __name__ == '__main__':
    sites = [json.loads(l) for l in open(RES)]
    sites = [r['site'] for r in sites if r.get('ok')]
    out = {}
    with cf.ThreadPoolExecutor(int(os.environ.get("SHOT_WORKERS", "8"))) as ex:
        for i, fut in enumerate(cf.as_completed([ex.submit(shot, x) for x in sites]), 1):
            try: s, m = fut.result()
            except Exception: continue
            if m: out[s] = m
            if i % 100 == 0: print(i, len(out), flush=True)
    json.dump(out, open(OUT, 'w'))
    print('done', len(out), 'of', len(sites))
