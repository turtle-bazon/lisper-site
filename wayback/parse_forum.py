#!/usr/bin/env python3
"""Парсер старого форума lisper.ru из зеркала Wayback (wayback/site/forum/).

Вход:  site/forum/thread/<id>.html (+ <id>/pageN.html — многостраничные)
Выход: forum_parsed.json
  { "categories": {slug: name},
    "threads": [ {"id", "url", "title", "category_slug",
                  "posts": [{"msg_id","author","date","body_html","reply_to"}],
                  "warnings":[...]} ],
    "stats": {...} }

Структура старой страницы:
  div.thread > div#forum-nav-panel > ul > li>a[/forum/<slug>] (категория)
  div.topic   > div>big=TITLE, div.topicbody=BODY,
                div.topic-info>span.topic-author>strong=AUTHOR - DATE
  div.reply id="comment-NNN" > div.replybody=BODY, div.topic-info
                ([#/] Ответ на .../messages/M от AUTHOR DATE) + автор в конце
"""
import json, os, re, sys, html as htmllib

ROOT = os.path.dirname(os.path.abspath(__file__))
FORUM = os.path.join(ROOT, 'site', 'forum')
OUT = os.path.join(ROOT, 'forum_parsed.json')

def read(p):
    try:
        return open(p, encoding='utf-8', errors='replace').read()
    except OSError:
        return None

def find_balanced_div(html, start):
    """start = позиция '<div' ; возвращает индекс закрывающей скобки блока."""
    i = start
    depth = 0
    for m in re.finditer(r'<div\b|</div>', html[start:]):
        if m.group(0) == '</div>':
            depth -= 1
        else:
            depth += 1
        if depth == 0:
            return start + m.end()
    return -1

def inner(html, open_end, close_start):
    return html[open_end:close_start]

def extract_block(html, cls):
    """Все блоки <div class="cls" ...>...</div> -> список внутреннего HTML."""
    out = []
    for m in re.finditer(r'<div\b[^>]*class="' + cls + r'"[^>]*>', html):
        end = find_balanced_div(html, m.start())
        if end > 0:
            out.append(inner(html, m.end(), end - len('</div>')))
    return out

AUTHOR_DATE_RE = re.compile(
    r'<strong>([^<]+)</strong>\s*-\s*(\d{2}\.\d{2}\.\d{4}\s+\d{2}:\d{2})')
REPLY_TO_RE = re.compile(r'Ответ на\s*<a href="/forum/messages/(\d+)">')
MSG_ID_RE = re.compile(r'id="comment-(\d+)"')
BREADCRUMB_RE = re.compile(r'<a href="/forum/([a-z0-9_-]+)">([^<]+)</a>')
TITLE_RE = re.compile(r'<big>(.*?)</big>', re.S)

def parse_thread(path, url_hint):
    html = read(path)
    if not html or 'class="topic"' not in html:
        return None
    warnings = []

    # категория из хлебных крошек nav-panel (имя + slug)
    nav_end = html.find('class="topic"')
    cat_slug = cat_name = None
    seg = html[html.find('forum-nav-panel'):nav_end if nav_end > 0 else None]
    cat_m = BREADCRUMB_RE.search(seg)
    if cat_m:
        cat_slug = cat_m.group(1)
        cat_name = htmllib.unescape(cat_m.group(2)).strip()

    posts = []
    title = None

    # --- первый пост (topic)
    topic_blocks = extract_block(html, 'topic')
    # блок class="topic" один; внутри него topic-info с автором идёт ПОСЛЕ body
    if topic_blocks:
        tb = topic_blocks[0]
        tm = TITLE_RE.search(tb)
        if tm:
            title = htmllib.unescape(re.sub(r'<[^>]+>', '', tm.group(1))).strip()
        bodym = re.search(r'<div class="topicbody">(.*?)(?=<div class="topic-info">)',
                          tb, re.S)
        body = bodym.group(1) if bodym else ''
        am = AUTHOR_DATE_RE.search(tb)
        author = am.group(1).strip() if am else None
        date = am.group(2) if am else None
        if not author:
            warnings.append('topic author/date not found')
        posts.append({'msg_id': None, 'author': author, 'date': date,
                      'body_html': body.strip(), 'reply_to': None})
    else:
        warnings.append('no topic block')

    # --- ответы
    for m in re.finditer(r'<div class="reply" id="comment-(\d+)"[^>]*>', html):
        msg_id = m.group(1)
        end = find_balanced_div(html, m.start())
        if end < 0:
            warnings.append(f'reply {msg_id}: unbalanced block')
            continue
        rb = inner(html, m.end(), end - len('</div>'))
        bodym = re.search(r'<div class="replybody">(.*?)(?=<div class="topic-info">)',
                          rb, re.S)
        body = bodym.group(1) if bodym else ''
        rt = REPLY_TO_RE.search(rb)
        reply_to = rt.group(1) if rt else None
        # автор ответа: последний topic-author strong в блоке
        authors = AUTHOR_DATE_RE.findall(rb)
        author, date = (authors[-1][0].strip(), authors[-1][1]) if authors \
            else (None, None)
        if not author:
            warnings.append(f'reply {msg_id}: author not found')
        posts.append({'msg_id': msg_id, 'author': author, 'date': date,
                      'body_html': body.strip(), 'reply_to': reply_to})

    return {'id': url_hint, 'title': title, 'category_slug': cat_slug,
            'category_name': cat_name,
            'posts': posts, 'warnings': warnings}

def main():
    categories = {}
    name_votes = {}
    threads = []
    stats = {'files': 0, 'threads': 0, 'empty_or_junk': 0, 'posts': 0,
             'warn_threads': 0}

    # треды: thread/<id>.html и thread/<id>/pageN.html
    thread_dir = os.path.join(FORUM, 'thread')
    jobs = []
    for f in sorted(os.listdir(thread_dir)):
        p = os.path.join(thread_dir, f)
        if os.path.isfile(p) and f.endswith('.html'):
            tid = f[:-5]
            jobs.append((p, tid))
            sub = os.path.join(thread_dir, tid)
            if os.path.isdir(sub):
                for pg in sorted(os.listdir(sub)):
                    if pg.endswith('.html'):
                        jobs.append((os.path.join(sub, pg),
                                     f'{tid}/{pg[:-5]}'))

    merged = {}
    for path, key in jobs:
        stats['files'] += 1
        t = parse_thread(path, key)
        if not t:
            stats['empty_or_junk'] += 1
            continue
        base_id = key.split('/')[0]
        if base_id in merged:
            # продолжение многостраничного треда — добавляем только ответы
            prev_ids = {p['msg_id'] for p in merged[base_id]['posts']}
            added = 0
            for post in t['posts']:
                if post['msg_id'] and post['msg_id'] not in prev_ids:
                    merged[base_id]['posts'].append(post)
                    added += 1
            if added == 0:
                stats['empty_or_junk'] += 1
        else:
            merged[base_id] = t
            stats['threads'] += 1

    from collections import Counter
    for t in merged.values():
        stats['posts'] += len(t['posts'])
        if t['warnings']:
            stats['warn_threads'] += 1
        threads.append(t)
        if t['category_slug']:
            name_votes.setdefault(t['category_slug'], Counter())[t['category_name']] += 1
    for slug, votes in name_votes.items():
        categories[slug] = votes.most_common(1)[0][0] or slug

    result = {'categories': categories, 'threads': list(merged.values()),
              'stats': stats}
    json.dump(result, open(OUT, 'w', encoding='utf-8'), ensure_ascii=False,
              indent=1)
    print(json.dumps(stats, ensure_ascii=False))
    print('categories:', categories)

if __name__ == '__main__':
    main()
