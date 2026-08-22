#!/usr/bin/env python3
"""Скачивает последние снапшоты всех URL старого lisper.ru из Wayback Machine.
id_/<ts>/<url> отдаёт сырой контент без тулбара archive.org.
Параллельно (ThreadPoolExecutor); структура зеркалит пути в wayback/site/.
MAXSEC=<сек> в окружении — мягкий лимит времени чанка (для запуска по частям).
"""
import json, os, sys, time, subprocess, re, threading
from urllib.parse import urlparse, quote
from concurrent.futures import ThreadPoolExecutor, as_completed

ROOT = os.path.dirname(os.path.abspath(__file__))
SITE_DIR = os.path.join(ROOT, 'site')
WORKERS = int(os.environ.get('WORKERS', '8'))
LOGLOCK = threading.Lock()
CNT = {'ok': 0, 'skip': 0, 'err': 0, 'done': 0}
_T0 = time.time()
MAXSEC = float(os.environ.get('MAXSEC', '100000'))

LOG = open(os.path.join(ROOT, 'download.log'), 'a', encoding='utf-8')
def log(*a):
    with LOGLOCK:
        print(*a); LOG.write(' '.join(map(str, a)) + '\n'); LOG.flush()

rows = json.load(open(os.path.join(ROOT, 'cdx_unique.json')))[1:]

def safe_name(url):
    u = url.replace('http://lisper.ru:80', '').replace('https://lisper.ru', '')
    p = urlparse(u if '://' in u else 'http://x' + u)
    path = quote(p.path, safe='/') or '/'
    if p.query:
        path += '@' + re.sub(r'[^A-Za-z0-9._-]', '_', p.query)[:60]
    base = os.path.basename(path)
    if '.' not in base:
        path += '.html'
    return path.lstrip('/')

def out_path(url):
    rel = safe_name(url)
    full = os.path.join(SITE_DIR, rel)
    os.makedirs(os.path.dirname(full) or SITE_DIR, exist_ok=True)
    return full

def fetch(idx, ts, url):
    dst = out_path(url)
    if os.path.exists(dst) and os.path.getsize(dst) > 0:
        CNT['skip'] += 1
        return
    wayback = f'https://web.archive.org/web/{ts}id_/{url}'
    code = ''
    for attempt in range(3):
        r = subprocess.run(['curl', '-s', '-L', '--http1.1', '--max-time', '90',
                            '--compressed',
                            '-w', '%{http_code}', '-o', dst, wayback],
                           capture_output=True, text=True)
        code = r.stdout.strip()
        size_now = os.path.getsize(dst) if os.path.exists(dst) else 0
        if code == '200' and size_now > 0:
            break
        time.sleep(1.5 * (attempt + 1))
    size = os.path.getsize(dst) if os.path.exists(dst) else 0
    if code == '200' and size > 0:
        CNT['ok'] += 1
    else:
        CNT['err'] += 1
        if os.path.exists(dst):
            os.remove(dst)
        log(f'FAIL {code} :: {url}')

total = len(rows)
with ThreadPoolExecutor(max_workers=WORKERS) as ex:
    futures = [ex.submit(fetch, i, ts, url)
               for i, (ts, url, st, mime) in enumerate(rows)]
    for f in as_completed(futures):
        f.result()
        CNT['done'] += 1
        if CNT['done'] % 50 == 0:
            el = time.time() - _T0
            log(f"[{CNT['done']}/{total}] ok={CNT['ok']} skip={CNT['skip']} "
                f"err={CNT['err']} ({el:.0f}s)")
        if time.time() - _T0 > MAXSEC:
            log(f"PAUSE-BY-TIMEOUT: done={CNT['done']} ok={CNT['ok']} "
                f"skip={CNT['skip']} err={CNT['err']}")
            for x in futures:
                x.cancel()
            break

log(f"CHUNK-DONE: done={CNT['done']}/{total} ok={CNT['ok']} skip={CNT['skip']} err={CNT['err']}")
