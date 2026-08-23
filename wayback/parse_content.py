#!/usr/bin/env python3
"""Парсер контента старого lisper.ru для импорта в блог (аккаунт oldlisper).

Источники (wayback/site/):
  * /articles/<lisp-slugs>.html   — Lisp-статьи (div.article, заголовок h3)
  * /wiki/*.html                  — wiki: Cookbook ru, FAQ, libraries
  * /2009/../2015/**/*.html       — посты блога archimag (div.post, span.date)

Выкидыши: altawin/optima/altek/окно-бизнес и служебные страницы.

Выход: content_parsed.json
  {"posts": [{"url","slug","title","date"(ISO),"body_html"}], "stats": {...}}

Даты: у блога — из span.date; у статей/wiki — дата capture из cdx_unique.json.
"""
import json, os, re, html as H
from urllib.parse import urlparse, unquote

ROOT = os.path.dirname(os.path.abspath(__file__))
SITE = os.path.join(ROOT, 'site')

# --- whitelist Lisp-статей в /articles/
LISP_ARTICLES = {
    'cl-vars', 'clisp-vs-sbcl', 'clos-initialization-protocol',
    'clos-method-combination', 'common-lisp-technologies',
    'connect-to-remote-lisp', 'eval-when', 'hello-world-with-cl-gtk2',
    'icfpc-2009-virtual-mashine', 'nikodemus-cl-faq', 'quicklisp',
    'restarts', 'rulisp-installation', 'sbcl-add-vop', 'sbcl-debugging',
    'sendind-smtp-mail-with-utf-8-characters', 'setf-vs-setq',
}

def read(p):
    try:
        return open(p, encoding='utf-8', errors='replace').read()
    except OSError:
        return None

def find_balanced_div(html, start):
    depth = 0
    for m in re.finditer(r'<div\b|</div>', html[start:]):
        depth += -1 if m.group(0) == '</div>' else 1
        if depth == 0:
            return start + m.end()
    return -1

def div_inner(html, cls, from_pos=0):
    """Внутренний HTML первого <div class="cls">...</div>."""
    m = re.search(r'<div\b[^>]*class="' + cls + r'"[^>]*>', html[from_pos:])
    if not m:
        return None
    end = find_balanced_div(html, from_pos + m.start())
    if end < 0:
        return None
    return html[from_pos + m.end():end - len('</div>')]

def clean_title(t):
    t = H.unescape(re.sub(r'<[^>]+>', '', t or '')).strip()
    return re.sub(r'\s+', ' ', t)[:250]

def cd_ts_iso(ts):
    """CDX timestamp YYYYMMDDhhmmss -> ISO datetime."""
    t = re.sub(r'\\D', '', ts or '')
    if len(t) >= 14:
        return f'{t[:4]}-{t[4:6]}-{t[6:8]} {t[8:10]}:{t[10:12]}:{t[12:14]}'
    if len(t) >= 8:
        return f'{t[:4]}-{t[4:6]}-{t[6:8]} 00:00:00'
    return None

def rfc_to_iso(s):
    """Fri, 06 Mar 2009 08:18:00 GMT -> 2009-03-06 08:18:00"""
    m = re.search(r'(\d{1,2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2})', s or '')
    if not m:
        return None
    months = {'jan':1,'feb':2,'mar':3,'apr':4,'may':5,'jun':6,
              'jul':7,'aug':8,'sep':9,'oct':10,'nov':11,'dec':12}
    d, mon, y, hh, mi, ss = m.groups()
    mo = months.get(mon.lower())
    return f'{y}-{mo:02d}-{int(d):02d} {hh}:{mi}:{ss}' if mo else None

def extract_author(h):
    """Имя автора/переводчика статьи lisper.ru по строке в шапке.
       Работаем по тексту без тегов (имена бывают внутри <a>/<strong>,
       двоеточие — до или после метки, метка не обязательно с начала строки).
       Варианты: 'Автор:', 'Автор :', '<strong>Автор</strong>:',
       'Автор перевода:', 'Перевод: Имя' (не URL!), 'Перевод Ивана Болдырева'."""
    plain = H.unescape(re.sub(r'(?is)<[^>]+>', '', h))

    def _cut(seg):
        for stop in ('Источник', 'Оригинальная', 'Оригинал', 'Добавление'):
            i = seg.find(stop)
            if i >= 0:
                seg = seg[:i]
        prev = None
        while prev != seg:
            prev = seg
            seg = seg.strip().strip('()').rstrip(',.;:- ').strip()
        return seg

    # 1) 'Автор:' / 'Автор :' / 'Автор перевода:' / 'Переводчик:'
    m = re.search(
        r'(?is)(?<![\wа-яё])(?:Автор\s+перевода|Автор|Переводчик)\s*:\s*(.{0,160})',
        plain)
    if m:
        name = _cut(m.group(1))
        if name and len(name.split()) <= 4 and '://' not in name:
            return name
    # 2) 'Перевод: Имя' (за двоеточием НЕ URL)
    m = re.search(
        r'(?is)(?<![\wа-яё])Перевод\s*:\s*(?!https?://|www\.)(.{0,160})', plain)
    if m:
        name = _cut(m.group(1))
        if name and '://' not in name and len(name.split()) <= 4:
            return name
    # 3) 'Перевод Ивана Болдырева' — родительный падеж без двоеточия;
    #    простая морфология: муж. родительный на -а/-я -> именительный
    m = re.search(
        r'(?<![\wа-яё])Перевод\s+((?:[А-ЯЁ][а-яё\-]+)(?:\s+[А-ЯЁ][а-яё\-]+){0,2})',
        plain)
    if m:
        words = clean_title(m.group(1)).split()
        while words and words[-1] in ('Добавление', 'Источник', 'Оригинал',
                                      'Оригинальная', 'Перевод'):
            words.pop()
        words = [w[:-1] if len(w) > 4 and w[-1] in 'ая' else w for w in words]
        if words and len(words) <= 3:
            return ' '.join(words)
    return None

def extract_blog_author(h):
    """Владелец блога из шапки страницы поста:
       v1: <h1 id="title"><a href="/">archimag</a></h1>
       v2: <div id="header"><a href="/" id="blogname">archimag</a></div>
       fallback: <title>archimap: 17 March, 2009</title> -> 'archimag'."""
    m = re.search(r'(?is)<h1[^>]*id="title"[^>]*>\s*<a[^>]*>([^<]+)</a>', h)
    if m:
        name = clean_title(m.group(1))
        if name:
            return name
    m = re.search(r'(?is)<div[^>]*id="header"[^>]*>\s*<a[^>]*id="(?:blogname|[\w-]+)"[^>]*>([^<]+)</a>', h)
    if m:
        name = clean_title(m.group(1))
        if name:
            return name
    m = re.search(r'(?is)<title>\s*([^:<]+?)\s*[:\u2014]', h)
    if m:
        name = clean_title(m.group(1))
        if name and len(name.split()) <= 3:
            return name
    return None

# сентинл для контента без авторства (вики) — переводится на клиенте/сервере
# через i18n-ключ :old-wiki при рендере
WIKI_AUTHOR = 'old-wiki'

def slug_from_url(url):
    path = urlparse(url).path.rstrip('/')
    seg = unquote(path.split('/')[-1])
    seg = seg.replace('%3A', ':')
    # кириллические слаги транслитерирует CL-сторона; здесь оставляем как есть,
    # ограничив длину и убрав опасные символы
    seg = re.sub(r'[^A-Za-z0-9_:.-]', '-', seg)
    return seg.strip('-')[:140] or 'post'

# Транслитерация кириллицы (как в src/blog.lisp *translit-table*) — слаги
# генерируем из ЗАГОЛОВКА, а не из URL (в зеркале Wayback каждая страница
# лежит дважды: numeric-имя и percent-encoded-имя -> дубли при импорте).
_TRANSLIT = {
    'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'e',
    'ж': 'zh', 'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm',
    'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u',
    'ф': 'f', 'х': 'h', 'ц': 'c', 'ч': 'ch', 'ш': 'sh', 'щ': 'sch', 'ъ': '',
    'ы': 'y', 'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya',
}

def translit(s):
    out = []
    for ch in (s or '').lower():
        if ch in _TRANSLIT:
            out.append(_TRANSLIT[ch])
        elif ch.isascii() and ch.isalnum():
            out.append(ch)
        else:
            out.append('-')
    return ''.join(out)

def slug_from_title(title):
    raw = translit(title)
    raw = re.sub(r'-{2,}', '-', raw)
    raw = raw.strip('-')
    return raw[:140] or 'post'

def main():
    cdx = json.load(open(os.path.join(ROOT, 'cdx_unique.json')))[1:]
    def _norm(u):
        u = u.replace('http://lisper.ru:80', 'http://lisper.ru')
        u = u.replace('https://lisper.ru:80', 'https://lisper.ru')
        p = urlparse(u).path
        # раскодируем percent-encoding до стабила и убираем .html,
        # чтобы сопоставлять файлы зеркала с записями CDX независимо
        # от регистров hex-цифр и числа кодирований
        prev = None
        while prev != p:
            prev = p
            p2 = unquote(p)
            if p2 != p:
                p = p2.lower()
        if p.endswith('.html'):
            p = p[:-len('.html')]
        return p
    ts_by_url = {}
    for ts, u, st, mt in cdx:
        p = _norm(u)
        if p not in ts_by_url or ts < ts_by_url[p]:
            ts_by_url[p] = ts

    posts = []
    stats = {'blog': 0, 'article': 0, 'wiki': 0, 'skipped': 0}
    seen_slugs = set()

    def add(url, title, date_iso, body_html, author=None):
        if not body_html or len(body_html.strip()) < 40:
            stats['skipped'] += 1
            return
        title_clean = clean_title(title) or slug_from_url(url)
        # слаг из заголовка + дедуп: зеркало Wayback хранит каждый пост
        # дважды (numeric-файл и percent-encoded-файл) -> одинаковый слаг
        slug = slug_from_title(title_clean)
        if slug in seen_slugs:
            stats['skipped'] += 1
            return
        seen_slugs.add(slug)
        posts.append({'url': url, 'slug': slug,
                      'title': title_clean,
                      'date': date_iso,
                      'body_html': body_html.strip(),
                      'author': author})

    # --- блог 2009-2015
    year_dirs = sorted(d for d in os.listdir(SITE)
                       if re.fullmatch(r'20\d\d', d))
    for ydir in year_dirs:
        for root, _, files in os.walk(os.path.join(SITE, ydir)):
            for f in files:
                if not f.endswith('.html'):
                    continue
                p = os.path.join(root, f)
                rel = os.path.relpath(p, SITE).replace(os.sep, '/')
                url = 'http://lisper.ru/' + rel[:-len('.html')]
                h = read(p)
                if not h:
                    continue
                if not re.search(r'/20\d\d/\d\d/\d\d/', url):
                    stats['skipped'] += 1
                    continue
                if 'class="blog-post"' in h:
                    # шаблон v2 (поздний блог): div.blog-post
                    bp = div_inner(h, 'blog-post')
                    if not bp:
                        stats['skipped'] += 1
                        continue
                    tm = re.search(r'<h2><a[^>]*>(.*?)</a></h2>', bp, re.S)
                    # дата из URL-путей года/месяца/дня или post-published
                    ym = re.search(r'/(20\d\d)/(\d\d)/(\d\d)/', url)
                    date_iso = (f'{ym.group(1)}-{ym.group(2)}-{ym.group(3)} '
                                '00:00:00') if ym else None
                    # тело: убираем заголовок и метаданные из начала
                    body = re.sub(r'^\\s*<h2>.*?</h2>', '', bp,
                                  count=1, flags=re.S)
                    body = re.sub(
                        r'(?:^|(?<=>))(\\s*<div class="post-metadata").*?'
                        r'</div>\\s*</div>(?=\\s)', '', body,
                        count=1, flags=re.S)
                    add(url, clean_title(tm.group(1)) if tm else '',
                        date_iso, body, extract_blog_author(h))
                    stats['blog'] += 1
                    continue
                if 'class="post"' not in h:
                    continue
                post_div = div_inner(h, 'post')
                if not post_div:
                    continue
                tm = re.search(r'<h2><a[^>]*>(.*?)</a></h2>', post_div, re.S)
                dm = re.search(r'<span class="date">([^<]+)</span>', post_div)
                body = div_inner(post_div, 'content') or ''
                add(url, clean_title(tm.group(1)) if tm else '',
                    rfc_to_iso(dm.group(1)) if dm else None, body,
                    extract_blog_author(h))
                stats['blog'] += 1

    # --- статьи (только Lisp-whitelist)
    art_dir = os.path.join(SITE, 'articles')
    for f in sorted(os.listdir(art_dir)):
        base = f[:-len('.html')] if f.endswith('.html') else f
        if not f.endswith('.html'):
            continue
        if base not in LISP_ARTICLES:
            stats['skipped'] += 1
            continue
        p = os.path.join(art_dir, f)
        url = 'http://lisper.ru/articles/' + base
        h = read(p)
        if not h:
            continue
        art = div_inner(h, 'article')
        if not art:
            stats['skipped'] += 1
            continue
        hm = re.search(r'<h3>(.*?)</h3>', art, re.S)
        def _lookup(url):
            p = _norm(url)
            return ts_by_url.get(p)
        ts = _lookup(url)
        date_iso = rfc_to_iso(ts or '') or (cd_ts_iso(ts))
        add(url, clean_title(hm.group(1)) if hm else base, date_iso, art,
            extract_author(h))
        stats['article'] += 1

    # --- wiki
    wiki_dir = os.path.join(SITE, 'wiki')
    for f in sorted(os.listdir(wiki_dir)):
        if not f.endswith('.html'):
            continue  # .lisp-файлы и прочее не страницы
        p = os.path.join(wiki_dir, f)
        name = unquote(f[:-len('.html')])
        url = 'http://lisper.ru/wiki/' + f
        h = read(p)
        if not h or 'class="article"' not in h:
            stats['skipped'] += 1
            continue
        art = div_inner(h, 'article')
        if not art:
            stats['skipped'] += 1
            continue
        tm = re.search(r'<title>([^<]*)</title>', h)
        ts = _lookup(url)
        date_iso = rfc_to_iso(ts or '') or (cd_ts_iso(ts))
        add(url, clean_title(tm.group(1)) if tm else name, date_iso, art,
            WIKI_AUTHOR)
        stats['wiki'] += 1

    posts.sort(key=lambda p: (p.get('date') or ''))
    json.dump({'posts': posts, 'stats': stats},
              open(os.path.join(ROOT, 'content_parsed.json'), 'w',
                   encoding='utf-8'),
              ensure_ascii=False, indent=1)
    print(json.dumps(stats, ensure_ascii=False))

if __name__ == '__main__':
    main()
