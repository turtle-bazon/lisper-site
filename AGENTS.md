# lisper — AGENTS.md

> **Правило**: при каждом изменении кода, обнаруженном баге, принятом решении или 새로운 тонкости — немедленно обновлять этот файл. AGENTS.md — живая документация проекта.

> **Ошибки**: НИКОГДА не подавлять ошибки молча. `(handler-case ... (error (e) nil))` запрещён. Всегда логировать через `console.log`. Молчание скрывает баги и ломает отладку.

> **Скриншоты**: когда пользователь говорит "посмотри скрин" — открывать файл `/tmp/screen.png`.

> **Скриншоты**: когда пользователь говорит "посмотри скриншот" — открывать файл `/tmp/screen.png`.

> **Таймауты**: максимальный таймаут для команд — 30000 мс (30 секунд).

> **Рефакторинг**: функция длиннее 40 строк должна быть разбита на меньшие функции СРАЗУ, как только это обнаружено. Не откладывать.

> **Education**: файлы в `education/` — авторитет. Всё что написано там имеет приоритет над любыми знаниями, догадками и находками извне. Если education говорит `#j"string"` — значит `#j"string"`, не `#j:String`, не CL-строка.

## О проекте
Сайт lisper — лендинг о Common Lisp. Всё на Lisp: HTML, CSS, JS.

## Бренд (2026-08)
- Бренд — **lisper** (домен-агностичный). Раньше был lisper.ru, теперь просто lisper.
- Причина: планируется ещё один домен, интернационализация.
- Хранить "lisper.ru" только как реальный URL репозитория-зеркала (GitHub), не как отображаемое имя.

## Стек
- **Сервер**: Clack + Wookie (`clack-handler-wookie`) `:debug nil`
- **HTML**: CL-WHO (`with-html-output-to-string` + `htm`)
- **CSS**: CL-CSS (`cl-css:css`)
- **JS**: plain string (Parenscript убран из-за конфликта readtable)
- **БД**: PostgreSQL 15 через `postmodern` (user=lisper, pass=lisper, db=lisper, host=127.0.0.1)
- **Аутентификация**: ironclad PBKDF2 (SHA-256, 100k iter), cookie-based sessions (30 дней)
- **Миграции**: SQL-файлы `migrations/NNNN-name.{up,down}.sql`, встроены в бинарник через `src/migrations.lisp`, таблица `schema_migrations`
- **Бинарник**: buildapp → `build/lisper` (~95MB)
- **Лицензия**: GPL-3.0
- **Исходники**: https://github.com/turtle-bazon/lisper-site (зеркало, основная СКВ — Mercurial)

## Интернационализация (2026-08-12)
- **Языки**: ru, en, tr, uk (*languages*). Словари — alist ключ→строка в `src/i18n-<lang>.lisp`, регистрируются через `register-dict`
- **Детект языка запроса** (`detect-language`, `src/i18n.lisp`): cookie `lang` → Accept-Language (q-переговоры) → суффикс домена (*domain-languages*, `.ru`→ru) → *default-language* ("en")
- **Динамическая переменная `*lang*`** связывается в `make-app` на каждый запрос; `*path*` — для ссылки «обратно» в переключателе
- **Переключатель языка — выпадающий dropdown** (`render-lang-switch`, `src/i18n.lisp`): кнопка `.lang-dropdown-btn` (label — native-имя текущего языка + caret `▾`) + меню `.lang-dropdown-menu` (native-имена всех языков, текущий `.active`). CSS `.lang-dropdown*` в `css.lisp`. Открытие/закрытие — `site-init-lang` в `jscl-tools/site.lisp` (клик по кнопке togglит класс `open`, `aria-expanded`; клик вне меню и Escape закрывают). Используется в шапке главной (`pages.lisp`) и форума (`forum-pages.lisp`)
- **`tr` / `tr-format`**: перевод с fallback default-язык → `?key`; `tr-format` + `format` args
- **Роуты**: `/set-lang?lang=..&next=..` (ставит cookie `lang`, редиректит на next/Referer/`/`) и `/i18n.js` (JS: `window.LISPER_LANG` + `window.LISPER_DICT`)
- **Клиентский словарь**: `*client-i18n-keys*` — ключи, попадающие в `window.LISPER_DICT` (игры, подсказки, md-редактор); `client-i18n-key-name` — `:hint-lisp-invaders` → `"hint-lisp-invaders"`
- **Подключение**: `<script defer src="/i18n.js">` ПЕРЕД jscl.js и site-бандлом (defer-скрипты выполняются по порядку; словарь готов к моменту инициализации site-бандла)
- **Клиент**: `tget`/`tget-or` в `site.lisp` читают `window.LISPER_DICT` (вернуть CL NIL, если словарь/ключ отсутствуют); игры, подсказки и md-empty берутся из словаря, fallback — английские строки
- **Версионирование `/i18n.js`**: НЕ версионируется (без `?v=`), но меняется per-request (зависит от cookie/заголовков) — кэшировать нельзя
- **`analytics-device-label`/`analytics-country-label`** (`forum-pages.lisp`): перевод хранящихся в БД меток устройств ('Мобильные'/'Десктоп') и 'Неизвестно'
- **Карточки** `*awesome-categories*`/`*cliki-categories*`: имена — ключи `:cat-*`/`:cliki-*`, рендер через `(tr key)` в `generate-cards`
- **Проверка полноты словарей**: все `(tr :key)` в коде должны быть определены во всех 4 словарях (сейчас 173 ключа, все покрыты)
- **Fix (2026-08-12)**: при переводе статических ответов `'(403 ... ("..."))` в `,(...)` НЕ забывать менять `'` на `` ` `` — иначе «Comma not inside a backquote». Аналогично: добавление `(cl-who:str (tr :key))` вокруг строки требует ровно +2 закрывающих скобки (по одной на `cl-who:str` и `tr`)
- **Fix (2026-08-12)**: `render-lang-switch` переписан с inline-ссылок (`<span class="lang-switch">RU EN TR UK`) на dropdown (`.lang-dropdown`). Клиентское открытие/закрытие — в site.lisp (`site-init-lang`, вызывается из `site-init`; Escape закрывает в `site-handle-keydown`). Старые CSS-классы `.lang-switch*` удалены из `css.lisp`

## Конфигурация
- S-expression `.conf` файл (host port и т.д.)
- Шаблон: `lisper.conf.template`
- **Порт по умолчанию**: 8080
- `:geo-db-path` — путь к `GeoLite2-Country.mmdb` (MaxMind DB); если нет/не найден — гео отключено, не фатально
- `:admin-secret` — секрет скрытого URL аналитики: `/analytics/<secret>` отдаёт дашборд без логина; неверный секрет → 404, `/admin/*` по-прежнему только по admin-сессии
- `:form-secret` — секрет HMAC антиспам-токенов форм (регистрация/логин); если не задан — fallback на `:admin-secret`

## Тонкости и баги

### Quicklisp + SBCL
- SBCL 2.6.5: `clack-handler-wookie` требует quicklisp dist ≥ 2026-01-01 (ironclad v0.50 не компилируется, нужен v0.61)
- SBCL HTTP client зависает на скачивании → обход через `QL-HTTP:*FETCH-SCHEME-FUNCTIONS*` с `curl`
- Сервер без PostgreSQL: обернуть `db-connect` в `handler-case` → стартует, главная работает, форум падает

## Тонкости и баги

### CL-WHO
- `with-html-output-to-string` требует `(htm ...)` для SXML-форм
- Raw-строки через `(cl-who:str ...)`
- **`:indent t`** добавляет пробелы между sibling-элементами — убрать, если не нужен
- Блочные элементы (`:h3`, `:p`) внутри `:a` вызывают проблемы в XHTML — переключиться на HTML5 через `:prologue "<!DOCTYPE html>"`
- SVG лого встроено через raw-строку `(cl-who:str "...")`
- Favicon — SVG лого через data URI в head
- Бейдж "Этот сайт написан на Common Lisp" — пункт списка с бейджем "НАШ САЙТ" в секции "Почему Common Lisp"
- Ресурсы (logo.svg, favicon.svg) хранятся в `resources/`, генерируются в `src/resources.lisp` через `build-resources.lisp`

### CL-CSS
- Селекторы — просто строки: `("body" :margin 0 ...)`
- **`:descendant` не поддерживается** — использовать plain селекторы
- **Float-литералы** рендерятся с `f0`: `1.6` → `"1.6f0"`. Исправлять через строку `"1.6"`
- Список правил должен быть `'(...)`, каждый rule — `(selector :prop val ...)`

### Clack + Wookie
- **`:server :woo`** — это Woo (другой сервер). У нас **`:server :wookie`**
- `clack:clackup` **не блокирует** — нужен `(loop (sleep 1))` в main
- `lack:builder` с `:pathinfo` middleware **недоступен** — использовать plain lambda
- Роутинг: читать `(getf env :path-info)` напрямую
- **`:debug nil`** — сервер молча убивает обработчик при ошибке, порт перестаёт слушать, но процесс жив; используем `:debug nil` когда все ошибки исправлены

### Readtable conflict
- SBCL 2.6.5: `cl-syntax-annot` (из ningle) модифицирует CL readtable
- Конфликтует с `named-readtables` (из parenscript)
- **Решение**: убрать ningle и parenscript, JS писать строкой

### Build
- `build.lisp` загружает зависимости через `ql:quickload`, затем `buildapp::main`
- `main` должен быть `(&optional args)`, не `(args)` — для вызова без аргументов
- Бинарник: `make build` → `build/lisper` (~95MB)
- **После изменений**: `make build`
- **Запуск дев-сервера**: `make dev-start` (лог в `/tmp/lisper.log`)
- **Остановка дев-сервера**: `make dev-stop`
- **Важно**: не запускать sbcl вручную — только через make. Прямые вызовы sbcl только для отладки проблем с make
- **Важно**: не запускать/останавливать сервер вручную — `pkill`, `rm -rf build`, `mkdir -p build` только если есть проблемы с make

### Безопасность
- **XSS через marked.js**: `marked.parse()` без санитизации → добавлен DOMPurify (`DOMPurify.sanitize()`) — **УСТАРЕЛО (2026-08-14)**: marked.js/DOMPurify удалены, markdown рендерит чистый CL-парсер `markdown:render-to-html` (raw HTML экранируется на этапе парсинга)
- **XSS через appendHTML()**: `div.innerHTML = html` → санитизация через DOMPurify, fallback на strip tags — **УСТАРЕЛО (2026-08-14)**: `dom-append-html` в repl.lisp переписан на `textContent`
- **highlight.js удалён (2026-08-15)**: внешних CDN-скриптов больше НЕТ — синтаксис Lisp подсвечивает чистый CL-парсер (см. «Подсветка синтаксиса» в разделе Markdown-парсер)
- **Security Headers**: CSP, X-Frame-Options: DENY, X-Content-Type-Options: nosniff, Referrer-Policy, X-XSS-Protection: 0
- **CSP + inline handlers**: CSP `script-src` без `'unsafe-inline'` блокирует `onclick=""` → заменить на `id` + `addEventListener` в JS
- **Timestamps**: PostgreSQL `TIMESTAMP` возвращает сырые числа → исправлено через `TO_CHAR(created_at, 'DD.MM.YYYY HH24:MI')` в SQL
- **Audit Log**: таблица `audit_log` + функция `log-audit` — логирует все действия модерации (delete, mute, unmute, set-role, toggle-forum)
- **JSCL safety**: проверка `typeof jscl === 'undefined'` перед использованием в loadScript callback

## Структура файлов
```
lisper.asd          — системное определение
Makefile            — make build
build.lisp          — скрипт сборки
build-resources.lisp — генерация src/resources.lisp из resources/ + JSCL-бандлы
lisper.conf.template
License.txt         — GPL-3.0
resources/
  logo.svg          — лого Common Lisp (фиолетовые цвета)
  favicon.svg       — favicon
jscl/
  jscl.js           — вендоренный JSCL runtime (module.exports, ставит self.jscl)
  jscl-node.js      — node-компилятор JSCL
jscl-tools/
  repl.lisp         — REPL-модалка на чистом CL (пакет :repl)
  site.lisp         — клиентский код сайта на CL (пакет :site, компилируется в /jscl-bundle/site)
jscl-games/
  lisp-invaders.lisp, lambda-runner.lisp, paren-matcher.lisp, s-dungeon.lisp
src/
  package.lisp      — пакет :lisper
  config.lisp       — чтение .conf файлов
  resources.lisp    — загруженные ресурсы (генерируется build-resources.lisp)
  game-sources.lisp — CL-коды игр (генерируется из jscl-games/; /game-source/<name>)
  tool-sources.lisp — CL-коды утилит (генерируется из jscl-tools/; /tool-source/<name>)
  jscl-bundles.lisp — скомпилированные JS-бандлы (генерируется build-resources.lisp)
  migrations.lisp   — встроенные SQL-миграции (генерируется из migrations/)
  db.lisp           — PostgreSQL + миграции
  auth.lisp         — регистрация, логин, сессии
  forum.lisp        — CRUD операции форума
  analytics.lisp    — аналитика: page_views, geo (cl-maxminddb mmap), уникальные посетители
  forum-pages.lisp  — HTML страницы форума
  css.lisp          — CL-CSS + raw media query
  js.lisp           — серверные хелперы URL/кэша (jscl-url, jscl-bundle-url)
  pages.lisp        — CL-WHO HTML (cat-card генерация)
  routes.lisp       — роутинг через path-info
  main.lisp         — entry point
```

## Секции на главной
1. **Header** — лого (ссылка на `/`) + навигация (Попробовать CL, Telegram, Форум, Игры) + учётка справа (Войти/Регистрация или имя+Выйти)
2. **Hero** — заголовок "Common Lisp - язык для тех, кто думает" + 3 кнопки (Попробовать CL, Форум, Telegram)
3. Что такое Common Lisp
4. Почему Common Lisp
5. **Реализации** — 6 карточек (SBCL, CCL, ECL, ABCL, LispWorks, Allegro CL)
6. **Редакторы и IDE** — две подсекции: "Готовые сборки" (Portacle, mine [NEW], Lem) и "Расширения и плагины" (SLIME, SLY, OLIVE [NEW], Alive, Slimv, Vlime, SLT [Экспериментальный], Slyblime)
7. **Экосистема** — 24 карточки awesome-cl.com (генерируются из `*awesome-categories*`)
8. **Вики** — 24 карточки cliki.net (генерируются из `*cliki-categories*`)
9. **Полезные ресурсы** — список ссылок (lisp-lang.org, HyperSpec, Cookbook, Quicklisp, Quickdocs, Exercism, Practical CL, On Lisp, common-lisp.net, Reddit)
10. Footer (ссылка на GitHub)
11. **REPL-модалка** — всплывающее окно с JSCL (Common Lisp в браузере)
12. **Lisp Игры** — секция с игровыми карточками (иконки + описание), открывающими модалку с canvas-игрой

## Реализации
- 6 карточек: SBCL, CCL, ECL, ABCL, LispWorks, Allegro CL
- Каждая карточка: заголовок, описание, ссылка "Сайт →"
- CSS: `.impl-grid` (3 колонки), `.impl-card`, `.impl-link`
- **Важно**: не выдумывать факты! CCL не поддерживает iOS/Android

## Карточки (awesome-cl / cliki)
- Генерируются функцией `(generate-cards categories base-url)`
- Формат: `(name slug color)` → `<a href='base-url#slug' class='cat-card' style='--accent: color'>name</a>`
- CSS grid: `repeat(auto-fill, minmax(180px, 1fr))`
- Цветная полоска слева через `::before` + CSS custom property `--accent`

## Запуск
```bash
# Через sbcl (для разработки):
sbcl --eval '(asdf:load-system :lisper)' --eval '(lisper:main)' --quit

# Через бинарник:
./build/lisper
```
Сервер слушает `0.0.0.0:8080`.

## JSCL-интеграция (REPL в браузере)
- Кнопка "Попробовать CL" в шапке рядом с Telegram
- По клику — модалка с REPL (jscl-project.github.io CDN)
- Кнопка: `id="try-repl-btn"` + `addEventListener` (не `onclick` из-за CSP)
- Ленивая загрузка: jscl.js (CDN или `/jscl.js`)
- `(exit)` / `(quit)` / `(si:quit)` закрывают модалку
- Escape тоже закрывает модалку
- **Custom terminal REPL** (не jqconsole) — свой input-элемент + appendLine/appendHTML
- Модалка: `.repl-overlay` → `.repl-modal` → `.repl-console` (div с `.repl-line` children)
- Стили в `css.lisp`: `.try-button` (зелёный), `.repl-overlay`, `.repl-modal`, `.repl-console`, `.repl-header`, `.repl-input`, `.repl-prompt-label`
- **Клиентский код — на CL** (см. «Site bundle» ниже): REPL-модалка, игры, markdown-редактор. JS-строки в `js.lisp` удалены
- **Site bundle (2026-08-12)**: `/js` и `generate-js` (JS-строка в `js.lisp`) **удалены**. Весь клиентский код переписан на CL в `jscl-tools/site.lisp` (пакет `:site`) и компилируется node-ом в бандл `/jscl-bundle/site`. `build-jscl-bundles` компилирует site.lisp ВМЕСТЕ с автогенерируемой прелюдией `build/jscl-bundles/site-prelude.lisp` (`(defpackage :site ...)` + `*site-bundle-urls*` — alist имя→`/jscl-bundle/<name>?v=<sha256>`, хеши бандлов считаются node crypto, совпадают с ironclad-хешами сервера). site.lisp исключён из `*tool-sources*` и из независимой компиляции бандлов. Подключение: `jscl.js` + `site.js`, оба `:defer t`, на главной (`pages.lisp`) и в `forum-render-head` (`forum-pages.lisp`). Маршрут `/js` удалён, `/game-source`/`/tool-source` оставлены
- **FFI-готчи (обязательны для site.lisp и всего клиентского кода)**:
  - **JS null/undefined/false/0/"" — truthy в CL!** `if`/`when`/`not` проверяют только `!== NIL-символ`. Проверка существования: `(eq el #j:null)` / `(eq v #j:undefined)`; булевы свойства (`shiftKey`, `disabled`) — через `jscl/ffi:clbool`
  - `el-by-id` возвращает CL NIL вместо JS null (чтобы `(when el ...)` работал); `document.activeElement`/querySelector — проверять `(not (eq x #j:null))` явно
  - Конвертеры: `jscl/ffi:jsstring` (CL→JS), `jscl/ffi:clstring` (JS→CL), `jscl/ffi:clbool` (JS bool→CL, на объектах type-error), `jscl/ffi:jsbool` (CL T/nil→JS)
  - Чтение свойства: `(jscl::oget obj "prop")` без вызывающих скобок; метод: `((jscl::oget obj "method") args)`
  - Кросс-пакетные вызовы (REPL/игры — отдельные бандлы): `jscl.packages[PKG].symbols[SYM].fvalue` → `(funcall fn ...)`/`(apply fn args)`; site.lisp оборачивает в `pkg-sym`/`pkg-fn`/`call-pkg-fn` (возвращают CL NIL если пакет/символ не найден)
  - `#j:true`/`#j:false`/`#j:null`/`#j:undefined` — настоящие JS-литералы; `#j:42` — НЕ число (использовать CL-числа)
  - **JSCL-lambda как JS-обработчик должен принимать event-аргумент** — браузер вызывает `onload`/`addEventListener`-колбэки с объектом события, а JSCL проверяет арность (`checkArgsAtMost`): 0-арговая лямбда кидает «too many arguments». Фикс: `(lambda (e) (declare (ignore e)) ...)`; `site-init` сделан `(&optional e)` из-за `DOMContentLoaded`. НЕ вызывать CL-функции напрямую как обработчики без учёта арности
- **Кеш jscl.js (2026-08-11)**: `/jscl.js` отдаётся с `Cache-Control: public, max-age=31536000, immutable` (2.4MB, меняется только при обновлении JSCL). URL версионируется автогенерируемым SHA-256 контента: `(jscl-url)` → `/jscl.js?v=<hash>`; хеш стабилен между сборками при неизменном бандле. Хелперы `jscl-url`/`jscl-cache-key`/`jscl-bundle-url`/`jscl-bundle-cache-key`/`string-replace-all` — в начале `js.lisp` (не в генерируемом `resources.lisp`)
- **Скомпилированные бандлы (2026-08-11)**: `jscl-tools/*.lisp` и `jscl-games/*.lisp` компилируются в JS НОДОЙ при `make build` (`build-jscl-bundles` в `build-resources.lisp`) → `src/jscl-bundles.lisp` (`*jscl-bundles*` — alist имя→JS, `get-jscl-bundle`). Отдаются на `/jscl-bundle/<name>` с `Cache-Control: public, max-age=31536000, immutable`; версионированный URL — `(jscl-bundle-url name)` → `/jscl-bundle/<name>?v=<sha256>` (хеш мемоизирован в `*jscl-bundle-cache-keys*`). Без node — пустая таблица + warning, билд не падает
- **Загрузка бандлов (2026-08-12)**: REPL/игры грузятся site-бандлом по URL из `*site-bundle-urls*` (прелюдия) через свой `load-script` (`<script>` + onload-колбэк). Игры запускаются через `START-<PKG>` + rAF-цикл `GAME-LOOP-RAW` (`game-tick`, `*game-loop-alive*`/`*game-loop-anim-frame*`); REPL — через `REPL-START`. Бандл сам находит runtime: `typeof require !== 'undefined' ? require('jscl') : window.jscl : self.jscl`; jscl.js ставит `self.jscl` (в браузере `self===window`). Вендоренный jscl.js (в `jscl/`) умеет `module.exports` — проверено в node: бандлы регистрируют пакеты и функции. Проверка site-бандла в node: `/tmp/run_site3.js` (DOM-стаб, 36 ассертов: REPL-флоу, игры, markdown-редактор, кросс-пакетные вызовы, keydown Escape) и `/tmp/run_site_md_built.js` (рендер markdown чистым CL-парсером, проверка hl-спанов в code-блоке, XSS-экранирование). После изменений в site.lisp/repl.lisp/markdown.lisp: `make build` + прогнать node-тесты + `./tests/markdown/run-tests.sh`
- **Fix (2026-06-22)**: сбалансированы скобки — overlay закрывался с 5 `)` вместо 4, лишняя `)` закрывала `:html` до `<script>`
- **Fix (2026-06-22)**: переписано на кастомный терминал — jqconsole не работал (создавал DOM-элементы на body вместо `#repl-console`)
  - Каждая строка вывода = `div.repl-line` (appendLine/appendHTML)
  - Ввод = `div.repl-input-line` с `span.repl-prompt-label` + `input.repl-input`
  - Оценка через `jscl.packages['COMMON-LISP'].symbols['EVAL']` (не jscl.eval)
  - Кредиты JSCL в шапке REPL
  - Статус загрузки: "Loading JSCL..." → "Loading JSCL compiler..." → "Loading web runtime..."
- **Важно**: CL-строки в JS: экранирование `\\` и `\"` для передачи в `lisp.eval()`
- **Fix (2026-06-23)**: пробел между промптом и вводом — CSS `gap: 8px` на `.repl-input-line`, `padding: 2px 0` на `.repl-input`
- **Fix (2026-06-23)**: незакрытые скобки — добавлена `isBalanced(input)` (проверяет `()`, `[]`, `{}`, строки, escape, комментарии `;`); `clEval()` бросает `Error('incomplete input')` если несбалансировано
- **Fix (2026-06-26)**: `readOneForm` не пропускал `;` комментарии внутри форм — скобки в комментариях (`; Read input from _ki array (JS updates _ki[0..4], CL reads here)`) считались реальными, depth ломался → обрезался `update` (form 35/37), `game-loop-raw` и `start-lisp-invaders` не вызывались. Исправлено: `if (c === ';') { while (pos < src.length && src[pos] !== '\\n') pos++; continue; }` в `readOneForm` перед подсчётом скобок
- **Fix (2026-06-28)**: `readForm` ломался на `#\(` character literals в CL-исходниках — `#\(` содержит `(` который `readForm` считал реальной скобкой, depth ломался → формы мержились. Исправлено: `if (c === '#' && p+1 < src.length && src[p+1] === '\\') { p += 3; continue; }` — пропускает `#\X` литералы (3 символа). `#(` (векторы) НЕ пропускаются — там реальные скобки
- **Fix (2026-06-28)**: REPL переписан с JS на CL (`jscl-tools/repl.lisp`): CL обрабатывает eval, print, prompt, balanced-check, exit; JS обрабатывает только DOM. Все функции с префиксом `repl-` в CL-USER (без отдельного пакета — `in-package` не сохраняется между form-by-form eval). JS вызывает через `jscl.CL['REPL-START']` и т.д.
- **Fix (2026-06-28)**: `window.replBridge` — JS-мост для CL-кода: `printLine`, `printHTML`, `createInputLine`, `removeInputLines`, `focusLastInput`, `closeRepl`. CL вызывает через `(jscl::oget (bridge) "printLine")`
- **Fix (2026-06-28)**: REPL полностью переписан — все JS-обёртки удалены из `js.lisp`. CL использует прямые FFI-вызовы (`jscl::oget`) для всех DOM-операций. JS обрабатывает только: `loadScript`, `evalToolSource`, `setupErrorHandler`, `openRepl` (инициализация), `closeRepl`, markdown-редактор, игры. Enter/Arrow/History полностью в CL (`repl-enter`, `repl-arrow-up/down`, `repl-restore-history`, `repl-history-push/length/current`). `*repl-history*` — JS-массив `(#j:Array)`, не CL-вектор. `repl-history-current` использует `(jscl::oget arr idx)`, не `"aref"`.
- **Fix (2026-06-28)**: `readForm` исправлен для `#\(` — пропуск `#\X` литералов. НО: `readForm` НЕ пропускает `#|...|# ` block comments и `#(...)` vectors. Block comments редки, `#(...)` содержит реальные скобки (правильно считает depth)
- **Fix (2026-06-28)**: `readForm` исправлен для `#\Newline` и других многосимвольных character literals — `p += 2` + skip `[a-zA-Z0-9]+` вместо `p += 3`
- **Fix (2026-06-28)**: JS-обёртки удалены из `js.lisp` — `appendHTML`, `setInputEnabled`, `getPromptText`, `makeDots`, `createInputLine`, `removeInputLines`, `isBalanced`, `submitInput`, `restoreHistory`, `replHistory`, `replHistoryIdx`, `replLines`/`window.replLines`. JS оставляет только: `loadScript`, `evalToolSource`, `setupErrorHandler`, `openRepl`/`closeRepl`, markdown-редактор, игры. Enter/Arrow/History полностью в CL
- **Fix (2026-06-28)**: `inp` scope bug в `repl-create-input-line` — `inp` был объявлен в `let` но использовался за его пределами (`focus`). Исправлено: перенос `appendChild`, `scrollTop`, `focus` внутрь `let`-блока `inp`
- **Fix (2026-06-28)**: `jscl/internals:xstring` не существует — пакет `jscl/internals` не найден. JS-строки из DOM (`inp.value`) конвертируются в CL-строки через `(jscl::oget #j:jscl "internals" "make_lisp_string")`. `jscl.internals` глобально доступен (строка 40 jscl.js: `var internals = (jscl.internals = Object.create(null))`)
- **Fix (2026-06-28)**: порядок функций — `repl-restore-history` перенесён перед `repl-arrow-up`/`repl-arrow-down`, которые его вызывают. Иначе JSCL предупреждает "function is undefined"
- **Fix (2026-06-28)**: `*repl-history*` инициализирован как `(#j:Array)` (JS-массив), не `#()` (CL-вектор). JS-массив нужен для `push`, `length` и индексного доступа из CL через `jscl::oget`
- **Fix (2026-06-28)**: `repl-restore-history` исправлен — `((jscl::oget entry "lines"))` пытался вызвать массив как функцию. Исправлено: `(jscl::oget entry "lines")` без лишних скобок
- **Fix (2026-06-28)**: `repl-history-current` исправлен — `(jscl::oget *repl-history* idx)` вместо `((jscl::oget *repl-history* "aref" idx))` (нет метода "aref" у JS-массивов)
- **Fix (2026-06-29)**: `classList.contains` в `repl-arrow-up`/`repl-arrow-down` — `((jscl::oget active "classList") "contains" ...)` пытался вызвать DOMTokenList как функцию. Исправлено: `((jscl::oget (jscl::oget active "classList") "contains") ...)` — сначала получить метод, потом вызвать
- **Fix (2026-06-28)**: CL string escaping для REPL — незакрытые `"` в `make_lisp_string('(repl-balanced-p "' + escaped + '")')` обрезали CL-строку → JS начинался с `)'))` → syntax error. Исправлено: `'(repl-balanced-p \\"' + escaped + '\\")'` — все `"` в JS экранированы как `\\"` в CL
- **Важно: CL string escaping**: JS-код внутри `generate-js` — это CL-строка. Всё экранируется по CL-правилам: `\\\\` → `\\` (один backslash в строке), `\\"` → `"` (не закрывает строку!). **Все `"` в JS-коде должны быть `\"` в CL-источнике**, включая: regex-литералы (`/"/g` → `/\"/g`), строковые литералы (`'\\"'` → `'\\\\\"'`), и вложенные `make_lisp_string` (`'(repl-submit "'` → `'(repl-submit \\"'`). Иначе CL-строка обрезается prematurely → JS-код ломается. Пример проверки: `python3 -c "... парсинг CL-строки ..."` — убедиться что декодированный JS корректен
- **Fix (2026-06-26)**: лишняя `)` в `lisp-invaders.lisp` строка 239 — `(setf *game-over* t))))))` → `(setf *game-over* t)))))` (6→5 closing parens). Depth на строке 239 был 4, 6 `)` давали depth=-1 → `readOneForm` не мог найти начало следующей формы
- **Fix (2026-06-26)**: конфликт `window._ac` — canvas `arc()` (line 417) и AudioContext (line 430) оба использовали `_ac`. AudioContext перезаписывал `_ac = null` → `draw-player` падал на `(#j:_ac ...)`. AudioContext переименован в `_actx`
- **JSCL строки в JS**: CL-строка `"shoot"` в JSCL — объект `{string: "shoot"}`, не JS-строка. Оператор `===` всегда `false`. Извлекать через `type.string` на JS-стороне. Функция `jscl::xstring` недоступна из CL-кода
- **JSCL FFI — паттерн вызова методов** (из `education/oscillator.html`):
  - `(jscl::oget obj "method")` — получить метод, `((jscl::oget obj "method") args)` — вызвать
  - `(setf (jscl::oget obj "prop") val)` — установить свойство
  - `(#j:Reflect:construct (or #j:AudioContext #j:webkitAudioContext) (#j:Array))` — создать объект (вместо `new`, который не работает для `#j:AudioContext`)
- **JSCL Canvas API** (из `education/canvas.html`):
  - Пример: `((jscl::oget ctx "fillRect") 50 50 100 100)` — работает
  - `fillStyle` ставится через `#j"tomato"` — **JS-строка**, не CL-строка (`"tomato"`)
  - CL-строки → JS: `(jscl/ffi:jsstring s)` — **не** `#j:String`!
  - `#j"string"` — reader macro создаёт нативную JS-строку (для литералов)
  - **Важно**: не выдумывать! Если education говорит `jscl/ffi:jsstring` — значит `jscl/ffi:jsstring`
- **JSCL this-binding** (доказано тестом 2026-06-27):
  - `((jscl::oget ctx "fillRect") args)` — работает! JSCL компилирует как `ctx["fillRect"](args)` (не извлекает метод в переменную)
  - Canvas API требует `this = CanvasRenderingContext2D` — и получает его через `ctx["fillRect"](args)`
  - Audio API аналогично — `((jscl::oget osc "connect") gain)` работает
  - JS-тест `var fn = ctx.fillRect; fn(...)` — **неправильная модель**, JSCL так не делает
  - **`defmacro` в JSCL**: не работает при form-by-form eval (`readOneForm` + `eval`). Макрос определяется, но при eval следующей формы вызывается как функция (не раскрывается). **Вывод**: макросы определять через JSCL REPL или `load`, не через form-by-form eval.
- **Fix (2026-06-26)**: CL-строки с `\n` — в CL-строках `\n` = literal `n` (escape), не newline. Для JS `\n` нужно писать `\\\\n` в CL-источнике (→ `\n` в памяти CL → `\n` в JS-выводе). `'\\n'` → `n`, `'\\\\n'` → `\n`. Это коснулось fix выше — первый вариант `'\\n'` не работал
- **Fix (2026-06-23)**: Wookie `:debug nil` — добавлено в `clack:clackup`, иначе сервер падает на первом запросе с ошибкой
- **Fix (2026-06-24)**: ironclad PBKDF2 — `derive-key` с `'ironclad:pbkdf2` (символ) не работает; использовать `pbkdf2-hash-password` convenience-функцию с `:digest :sha256 :iterations 100000`
- **Fix (2026-06-24)**: `get-category-by-slug` — malformed plist из `(apply #'list (cons :id (first row)))`; исправлено через `destructuring-bind` с 4 полями (id name slug description)
- **Fix (2026-06-24)**: `get-form-value` — `gethash` на nil при GET-запросах (parsed-body = nil); добавлен nil-check
- **Fix (2026-06-24)**: `/new-topic?category=` GET — читать category из `:query-string`, не из POST body
- **Fix (2026-06-24)**: `delete-post` — `postmodern:query ... :single` возвращает скаляр, не строку; исправлено на `first` от списка строк
- **Fix (2026-06-24)**: `delete-post` UPDATE — `$1` использовался дважды с двумя параметрами; исправлено на один параметр
- **Fix (2026-06-24)**: UTF-8 mojibake — `url-decode` обрабатывал `%XX` как code-char (Latin-1), не как байты UTF-8; исправлено: накапливать байты в `(unsigned-byte 8)` массив, затем `flexi-streams:octets-to-string :external-format :utf-8`
- **Fix (2026-06-24)**: `get-all-users` возвращал raw rows (списки), не plists; `getf :id` возвращал nil → ошибка "invalid input syntax for type integer: false"; исправлено через `destructuring-bind` в `get-all-users`
- **Fix (2026-06-24)**: `is-muted-p` — не нужен `local-time`; использовать SQL `NOW()` в запросе: `SELECT 1 FROM users WHERE id = $1 AND muted_until > NOW()`
- **Fix (2026-06-24)**: `routes.lisp` paren mismatch — лишняя `)` в первом cond-clause `(page-index user)` закрывала `cond` досрочно; все последующие cond-clauses читались как top-level code → "illegal function call"
- **Дизайн (2026-06-24)**: Новый хедер — лого слева (ссылка на `/`), навигация по центру (Попробовать CL, Telegram, Форум), учётка справа (Войти/Регистрация или имя+Выйти). Hero-секция вынесена из хедера в отдельный `.hero` div с заголовком и 3 кнопками (`.hero-try-button`, `.forum-button`, `.telegram-button`). Старые стили `.logo-container`, `.header-buttons`, `.forum-link`, `.user-info`, `.logout-link`, `.login-link`, `.admin-link` заменены на `.site-header`, `.header-nav`, `.header-right`, `.header-user`, `.header-logout`, `.header-login`, `.header-register`, `.header-admin`
- **Иконки (2026-06-24)**: Lucide SVG встроены прямо в Lisp-код (никаких CDN). Terminal для REPL, официальный Telegram logo (круг #229ED9 + белый самолётик), MessageCircle для форума, House для главной. CSS `.nav-icon svg` — 16×16, `stroke: currentColor` для Lucide, заливка для Telegram.
- **Ссылка на Telegram**: `tg://resolve?domain=commonlisp_ru` (не https://t.me/)

## Форум
- **Страницы**: `/forum`, `/forum/{slug}`, `/topic/{id}`, `/new-topic`, `/login`, `/register`, `/logout`, `/user/{username}`
- **POST-роуты**: `/login`, `/register`, `/new-topic`, `/new-post`, `/delete-post`, `/delete-topic`, `/admin/mute`, `/admin/unmute`, `/admin/set-role`, `/admin/toggle-forum`
- **Админ**: `/admin/users` — список всех пользователей (только для admin)
- **POST-body**: `parse-post-body` читает `raw-body` stream → URL-decode → hash-table
- **Категории**: 4 (general, projects, help, news) — seed в миграции 0001
- **Роли**: user, moderator, admin (поле `role` в `users`)
- **Сессии**: cookie `session=HEX`, таблица `sessions`, TTL 30 дней
- **Мут**: `muted_until` timestamp на users; проверяется перед созданием topic/post; PostgreSQL `NOW()` для сравнения
- **Настройки**: таблица `settings` (key/value), флаг `forum_closed` для закрытия форума

### Модерация
- **Админ**: может назначать/снимать модераторов, мутить/размьютить, удалять топики/посты, видеть список пользователей
- **Модератор**: может мутить/размьютить, удалять топики/посты, НЕ может назначать модераторов
- **Пользователь**: может создавать топики, отвечать, удалять свои посты
- **Гость**: только просмотр
- **Профиль пользователя**: `/user/{username}` — статистика (темы, сообщения), панель модерации (мут, роль) для модераторов/админов
- **В хедере**: лого ссылается на `/`, имя пользователя — ссылка на профиль, ссылка "Админ" для admin

### Auth
- `hash-password` → `ironclad:pbkdf2-hash-password` (SHA-256, 100k iter), формат `HEX_SALT:HEX_KEY`
- `verify-password` → `pbkdf2-hash-password` с `:salt`, `equalp` сравнение
- `register-user` → INSERT + `cl-postgres:database-error` при уникальности
- `authenticate-user` → SELECT + verify → `create-user-session`
- `current-user` → `extract-session-token` (из `(getf env :headers)` hash-table) → `get-user-by-session`
- `get-user-by-id`, `get-user-by-name` — возвращают plist с `:id :username :email :role :muted-until :created-at`
- `get-user-topic-count`, `get-user-post-count` — подсчёт для профиля
- `get-all-users` — список всех пользователей (plist), с `destructuring-bind`
- `mute-user`, `unmute-user` — установка/снятие `muted_until` (interval string)
- `set-user-role` — смена роли (admin only)
- `is-muted-p` — SQL `SELECT 1 ... WHERE muted_until > NOW()`
- **Важно**: `(getf env :headers)` — это hash-table, не строка; искать через `(gethash "cookie" headers)`
- **Важно**: `(getf env :headers)` — это hash-table, не строка; искать через `(gethash "cookie" headers)`

### Миграции
- **Встроены в бинарник** через `src/migrations.lisp` — не нужно таскать папку `migrations/`
- Таблица `schema_migrations`: version (int PK), name, applied_at
- `get-available-migrations` — возвращает список из `*migrations*`
- `get-migration-sql` — получает SQL из `*migrations*` по version и direction (:up/:down)
- `apply-migration` — split SQL by `;` + execute each via `postmodern:query` (не multi-statement)
- **Fix (2026-08-11)**: `apply-migration` сначала вырезает полнострочные комментарии `--` (`strip-sql-comments`) — иначе `;` в комментарии ломал сплит (миграция 0006 падала на фрагменте "drop the PostgreSQL copy."), а фрагмент «комментарий+SQL» мог целиком быть пропущен как комментарий
- **При добавлении новой миграции**: создать SQL-файлы, `make build` сам регенерирует `src/migrations.lisp` (шаг `embed-resources`)

### Антиспам (расширен 2026-08-21, `src/antispam.lisp`)
- **Регистрация/логин открыты** (2026-08-21): self-hosted email+пароль, БЕЗ внешней авторизации. Формы восстановлены в `forum-page-login`/`forum-page-register` (i18n, honeypot, скрытый токен `fts`)
- **Rate limiting** — in-memory sliding window (`rate-allowed-p key limit window`, таблица `*rate-table*` + чистка `rate-maybe-cleanup` раз в ~1000 вызовов): регистрация ≤5/час/IP, логин ≤10/15мин/IP. IP через `request-ip` (X-Real-IP/XFF), без заголовков — общий бакет "unknown" (за прокси все легитимные юзеры имеют реальные IP; прямые боты по IP душатся коллективно)
- **HMAC таймстамп-токены форм** (`make-form-token` → `"ts:hmac"`, `verify-form-token`): подпись SHA-256 секретом `:form-secret` (fallback `:admin-secret`); форма валидна только если отправлена через ≥2с после рендера и ≤24ч — слепые POST-боты отсекаются (`:auth-too-fast`)
- **Honeypot CAPTCHA** на регистрации — скрытое поле `website`, боты его заполняют, humans нет; при срабатывании — generic «register-failed», причину не раскрываем
- **Анимированная noise-CAPTCHA** (2026-08-21, заменила арифметическую, `make-captcha`/`verify-captcha`): 4 цифры 7-сегментными штрихами (SVG `<line>`, текста в разметке НЕТ), каждая видна только в своём слоте времени (`<animate opacity>` discrete, цикл 2.4с, слот 0.6с) поверх ~110 мерцающих rect-ов шума — как на AliExpress; человек «досматривает» кадры глазами. Stateless: код спрятан в HMAC-токене `ts:hmac(ts:код)` (`captcha-token`), проверка = перподписать ответ и сравнить mac (`verify-captcha`, нормализация — string-trim, НЕ parse-integer: ведущие нули!). Джиттер координат ±1px + случайный stroke-width/поворот на каждый запрос — фиксированную карту сегментов парсить нельзя. **Известное ограничение**: мотивированный атакующий всё же декодирует по форме штрихов (наш python-тест так и делает — nearest-midpoint классификация); против LLM-ботов следующая ступень — proof-of-work или email verification. Только на регистрации; логин защищён rate limit + fts. **CL-WHO-тонкости**: markup внутри runtime-форм (`let`) требует явного `(cl-who:htm ...)` — без него `(:input ...)` эвалюируется как функция («The function :INPUT is undefined»); `multiple-value-bind` в cl-who тоже не работает
- **Bot-UA блок** — `bot-user-agent-p` (из analytics) на POST /register: curl/wget/python-боты получают generic «register-failed» ещё до honeypot/captcha. Тестировать auth-endpoints curl-ом нужно с `-A "Mozilla/5.0 ..."`!
- **Валидация**: username 3–20 `[A-Za-z0-9_]` (`valid-username-p`, CL: `alphanumericp` — НЕ `char-alphanumericp`, его нет!), email базовая проверка (`valid-email-p`), пароль 8–128 (`valid-password-p`)
- **Троттлинг постинга** (`posting-throttled-p`, 30с): не чаще 1 поста/топика на пользователя (MAX(created_at) по posts+topics UNION); редирект `/new-topic?throttled=1` или `/topic/N?throttled=1`, notice рендерится в обеих страницах (`forum-page-topic`/`forum-page-new-topic` получили optional `throttled` аргумент)
- **Сессия**: cookie теперь `HttpOnly; SameSite=Lax` (`auth-session-cookie` в routes.lisp)
- **Согласие с правилами/GDPR** (2026-08-21): на регистрации обязательный чекбокс «согласен с правилами и обработкой персональных данных» (native HTML5 `required`, без JS) + серверная проверка `(gethash "agree" body)` → иначе «register-must-agree». Страница `/rules` (`forum-page-rules`): правила форума (4 пункта) + GDPR-блок (что храним: username/email/PBKDF2-хеш/посты; аналитика — IP/UA/страна/страницы, сырьё 7 дней, vid только как SHA-256 хеш cookie; цели; права — запрос через Telegram/тему на форуме). Все тексты i18n-ключи (:rules-* :privacy-* :i-agree :rules-link :register-must-agree) во всех 4 словарях
- **Закрытие форума** — флаг `forum_closed` в таблице `settings`, админ может закрыть/открыть через `/admin/toggle-forum`
- Когда форум закрыт: обычные пользователи не могут создавать топики/посты, админы могут
- Статус форума виден в админке: "ОТКРЫТ" (зелёный) / "ЗАКРЫТ" (красный) + кнопка toggle

### Аудит
- Таблица `audit_log` (id, user_id, action, target_type, target_id, details, created_at)
- Функция `log-audit` в `forum.lisp` — логирует все действия модерации
- Действия: delete-post, delete-topic, mute-user, unmute-user, set-role, toggle-forum
- Вызывается из handlers в `routes.lisp` после каждого действия

### Редактор постов
- **Markdown** — посты хранятся как raw markdown, рендерятся клиентски чистым CL-парсером `markdown:render-to-html`
- **Подсветка кода** — чистый CL-парсер `markdown:highlight-lisp` на этапе рендера (внешних CDN-скриптов нет)
- **Тулбар** — жирный, курсив, заголовки, списки, цитаты, код, ссылки, картинки, превью
- **Превью** — кнопка 👁 переключает между редактированием и предпросмотром
- **Компонент**: `forum-render-editor` — переиспользуемый для new-topic и reply
- **Клиентский рендеринг**: `.md-content` класс рендерится site-бандлом (`render-markdown-to`) при загрузке страницы

## Отчёт по безопасности (24.06.2026)
Полный отчёт в `/tmp/report.txt`. Исправлено:
1. **Stored XSS через marked.js** → DOMPurify санитизация — **УСТАРЕЛО (2026-08-14)**: markdown рендерит чистый CL-парсер, raw HTML экранируется
2. **XSS через appendHTML()** → DOMPurify санитизация, fallback strip tags — **УСТАРЕЛО (2026-08-14)**: `dom-append-html` → `textContent`
3. **Нет SRI** → integrity + crossorigin на всех CDN-скриптах и CSS
4. **Нет Security Headers** → CSP, X-Frame-Options: DENY, X-Content-Type-Options: nosniff, Referrer-Policy, X-XSS-Protection: 0
5. **Таймстемпы** → `TO_CHAR(created_at, 'DD.MM.YYYY HH24:MI')` в SQL
7. **Unsafe script loading** → `typeof jscl === 'undefined'` проверка перед использованием
9. **Нет аудита** → таблица `audit_log` + `log-audit()` для всех действий модерации

## Lisp Игры
- Секция на главной с карточками игр (иконки SVG + название + описание)
- Клик по карточке открывает модалку с canvas-игрой
- **Lisp Invaders** — клон Space Invaders с лисп-тематикой:
  - Враги: `defun` (красные, 10 очков), `lambda` (жёлтые, 15), `car` (синие, 20), `cdr` (фиолетовые, 20), `quote` (розовые, 25), `cons` (бирюзовые, 30)
  - Корабль игрока: `defun`-форма
  - Стреляет скобками (пробел)
  - Управление: ← →移动, P — пауза, Enter — заново
  - HUD: очки, жизни (♥), уровень
- **Lambda Runner** — endless runner с лямбдой:
  - Лямбда бежит через лес замыканий
  - Препятствия: замыкания (серые), компиляторы (красные), ловушки (жёлтые)
  - Коллекти: карри (+50 очков)
  - Управление: пробел — прыжок, P — пауза, Enter — заново
  - Прогрессия: скорость растёт со временем
- CSS: `.games-grid`, `.game-card`, `.game-overlay`, `.game-modal`, `.game-body`, `.game-footer`
- JS: `openGame()`, `closeGame()`, `startLispInvaders()`, game loop с requestAnimationFrame
- Кнопка "Игры" в хедере скроллит к секции
- **Ввод**: клавиатура через CL `(make-array 256)` + `aref` (не hash-table — `equal` не работает с JS numbers)
- **Звук**: полностью в CL через JSCL FFI (`*ac*` AudioContext, `play-snd`)
- **Загрузка игр**: `evalGameSource(source, name)` динамически ищет пакет `{name}` и функции `{name}:start-{name}`, `{name}:game-loop-raw`
- **S-Expression Dungeon** — реиграбельный пошаговый roguelike (в игре с 2026-06-27):
  - **Генерация**: комнаты (tile 1) без пересечений + L-образные коридоры по цепочке `(car (last conn))`; stairs (tile 3) в первой сгенерированной комнате, игрок стартует в последней
  - **Враги** (`*enemies*`): void-fn (V, 3hp/1dmg/10xp), wrong-type (W, 4/2/15), unbound (U, 2/1/8), overflow (O, 6/3/25), null-ref (N, 3/2/12) — плэйснется по 1-2/комнату, кроме стартовой; ходят к игроку (диагональ + fallback по вертикали)
  - **Лут** (`*items*`): defun (λ, heal +3), defmacro (M, +maxHP), setf (=, +dmg), progn (+, heal +6)
  - **Ход**: игрок (стрелки/WASD, `.` = wait) → `move-enemies`; атака врага при шаге на клетку без занятия её; стены (tile 0) блокируют
  - **Прогрессия**: XP → level (lvl×20), уровень = +2 maxHP/+1 dmg; камера следует за игроком, minimap справа, HUD с HP/DMG/Lvl/Fl/Score/Best
  - **Death = permadeath**: game over экран + Enter → `reset-game` (счётчик Best сохраняется)
  - **Звук**: `snd-*` серии через `play-snd` (AudioContext, `ensure-audio-ctx`)
- **Порт**: 8080

## Аналитика (2026-08)
- Своя серверная аналитика в PostgreSQL: таблица `page_views` (id, visitor_id, path, referrer, user_agent, ip, country, is_bot, created_at). Гео — НЕ в БД, см. ниже
- Миграции: **0005** (`page_views`), **0006** (drop `ip_country`), **0007** (`daily_stats`), **0009** (`browser`/`os` в daily_stats)
- **Безопасность хранения (ретеншен, 2026-08-11)**: сырые `page_views` живут `*analytics-raw-retention-days*` = 7 дней (окно дашборда), потом сворачиваются в `daily_stats` и удаляются. Рост ограничен: ~7 дней сырых + ~1-2k строк агрегатов/день
  - `daily_stats (date, path, country, device, browser, os, referrer, is_bot, views)` — аддитивно по всем измерениям, PK по всем колонкам кроме views. «OLAP для бедных»
  - `analytics-run-rollup` — один проход: `INSERT ... SELECT ... WHERE created_at < NOW() - interval '7 days' GROUP BY ... ON CONFLICT DO NOTHING` (device через CASE по user_agent, country через COALESCE('Неизвестно')) + `DELETE` свёрнутых строк. Идемпотентный, глотает ошибки с `console.log`, no-op без БД (`*db-available*`)
  - Запуск: в `main.lisp` при старте + фоновый поток `analytics-rollup-loop` (sb-thread, `(sleep 86400)`)
  - `analytics-total-views` = `COUNT(page_views) + COALESCE(SUM(daily_stats.views),0)`; окна 24ч/7д читают только сырые строки (в пределах 7 дней буфера) — дашборд не переписывали
  - Уникальность и «Последние визиты» из агрегатов не выводятся (не аддитивны / нужны сырые IP+UA) — потому и держим 7-дневный буфер сырья
- **Анализируемые HTML-страницы** (`analytics-tracked-path-p`): `/`, `/forum`, `/new-topic`, `/login`, `/register`, `/forum/*`, `/topic/*`, `/user/*`. CSS/JS/jscl.js/game-source/tool-source/admin НЕ трекаются
- **Уникальный посетитель**: cookie `vid` (16 байт hex, Max-Age 31536000, HttpOnly) → в БД хранится `SHA-256(cookie)` первые 32 hex (не сырые данные). Новый `vid` ставится через `Set-Cookie`
- **Логирование** в routes.lisp через `maybe-track-analytics` (оборачивает `make-app` cond): только GET + HTTP 200; ошибки логируются в консоль, ответ не ломается (важно: без БД главная работает)
- **Боты**: `bot-user-agent-p` — маркеры (googlebot, bot, curl, wget и т.д.), колонка `is_bot`; сводка ботов на дашборде
- **Гео — MaxMind DB в памяти** через `cl-maxminddb` (чисто-лисповый ридер, mmap; НЕ libmaxminddb):
  - `make-mmdb` при старте (`init-geo` в main.lisp), путь из конфига `:geo-db-path` (`lisper.conf`)
  - `country-for-ip` → `cl-maxminddb:mmdb-query` + `get-in record :country :names :en` (fallback `:registered-country`/`:iso-code`)
  - `mmdb-query` **бросает ошибку** "The address ... is not in the database" для не-гео IP (127.0.0.1 и т.п.) — это нормальный miss, обрабатывается как NIL без лога
  - Файл `.mmdb` (GeoLite2-Country.mmdb) качается вручную с MaxMind, в репозиторий не вшит; обновление = замена файла + рестарт
  - Важно: для сборки `cl-maxminddb` нужен build-time `pkg-config` + `libffi-dev` (cffi-grovel для `cffi-libffi`, который в asd либы заявлен, но кодом не используется)
- **Дашборд**: `/admin/analytics` (только admin) и скрытый `/analytics/<secret>`: stat-карточки (всего/24ч/7д просмотры + уникальные + боты + люди + доля людей), тренд (30 дней), топ страниц, источники, страны (если mmdb загружен), устройства (mobile/desktop), последние 30 визитов
- **Бот-фильтр**: агрегаты включают ботов (страны/устройства/источники), есть отдельная карточка «Боты»
- **Перф**: INSERT на каждый просмотр страницы; индексы (created_at, visitor_id, path)

### Аналитика (2026-08-13) — люди отдельно от ботов, тренд, языки, источники
- **Вкладки дашборда**: `?tab=all|people|bots` (UI — только «Все» и «Только люди»), парсится `analytics-parse-tab`, все запросы получают bot-filter и вставляют фрагменты `analytics-bot-where`(без WHERE)/`analytics-bot-and`(с WHERE): `is_bot = FALSE`/`TRUE`/''. Вкладки рендерятся с базовым роутом `tab-base` (`/admin/analytics` или `/analytics/<secret>`), т.к. страница доступна по двум URL
- **`analytics-people-unique-since`** — уникальные не-бот посетители; **`analytics-people-share-since`** — доля людей %; статистика-карточки «Люди · 7 дней» и «Доля людей» добавлены к дашборду
- **Тренд**: `analytics-daily-trend` — просмотры/день за 30 дней без пропусков дат: `generate_series` + LEFT JOIN UNION (page_views за буферный период + daily_stats за старые), gap-дни заполняются 0, метка `TO_CHAR(d,'DD.MM')`. Рендер — CSS-бары `.trend-chart`/`.trend-bar*` (height % от max). Значение дня выводится над каждым баром `.trend-bar-value` (раньше было только в `title`-тултипе — непонятно)
- **Источники (refactoring 2026-08-13)**: `analytics-top-referrers` возвращает только ВНЕШНИЙ хост источника: `split_part(substring(referrer FROM 'https?://([^/]+)'), ':', 1)` — режем scheme+path+`www.`+port. Внутренние реферы исключаются SQL-фрагментом `analytics-internal-referrer-clause` (own-hosts из заголовка Host запроса + всегда localhost/127.0.0.1/::1; `www.`+host; хвосты экранируются `''`, т.к. Host — атакующий ввод). **Важно**: строка с портом (`localhost:8080`) не равна хосту без порта — режем порт с ОБЕИХ сторон
- **Язык**: миграция **0008** `ALTER TABLE page_views ADD COLUMN lang TEXT`; `log-page-view` пишет `*lang*` (какой UI-язык был отдан). Блок «Языки (7 дней)» `analytics-top-langs` (COALESCE(lang,'?') — старые строки без языка; работает только по сырому буферу ~7 дней, в daily_stats lang нет). i18n-ключи: `:people-7d :people-share :filter-all :filter-people :trend :langs :language`
- `forum-page-analytics` изменил сигнатуру на `(user &optional (bot-filter :all) (own-hosts nil) (tab-base "/admin/analytics"))` **Тонкость Edit-тула**: во всех страницах одинаковый футер `(:footer ... " &copy; 2026 | GPL-3.0"))...` — правка количества `)` по одному футеру может примениться к ДРУГОМУ идентичному футеру. Диагностика несбалансированности: читать через SBCL `(asdf:load-system :lisper)` (ошибка READ с Line/Column), а не считать скобки скриптом — наивные счётчики путаются на `#\;`/`#\(` char-литералах и дают «сбалансировано» при фактическом несбалансе
- **Fix (2026-08-13)**: в `analytics-internal-referrer-clause` эскейпинг хостов был `(string-replace-all h "'" "''")` — аргументы перепутаны (сигнатура `string-replace-all` — `(needle replacement haystack)`), искалось `h` внутри литерала `"''"` → `NOT IN` деградировал до `('''','''','''')` и внутренние хосты НЕ исключались (sources показывал `localhost`). Исправлено на `(string-replace-all "'" "''" h)`. Диагностика: временные `format t` в `analytics-top-referrers`/`analytics-internal-referrer-clause` (удалены после фикса)

### Аналитика (2026-08-13) — браузеры и ОС (всё время, через rollup)
- **Миграция 0009** `add-browser-os`: `ALTER TABLE daily_stats ADD COLUMN browser TEXT NOT NULL DEFAULT 'Unknown'`, то же `os`; PK пересоздан: `DROP CONSTRAINT daily_stats_pkey` → PK `(date, path, country, device, browser, os, referrer, is_bot)` (проверено: имя старого PK — `daily_stats_pkey`). Имя миграции-файла: `migrations/0009-add-browser-os.{up,down}.sql`
- **Блоки дашборда** «Браузеры (всё время)» и «ОС (всё время)» — после блока «Устройства». Рендер: `analytics-ua-breakdown` (UNION сырого буфера page_views 7д + daily_stats) → `analytics-top-browsers`/`analytics-top-os`. **Тонкость SQL**: в первом подзапросе (page_views) CASE-выражение по `user_agent` в SELECT без GROUP BY → PostgreSQL 42803 «столбец должен фигурировать в GROUP BY» — нужен `GROUP BY label` (Postgres разрешает группировку по алиасу) в подзапросе; второй подзапрос (daily_stats) группировку НЕ требует (views уже агрегированы)
- **`analytics-browser-case`/`analytics-os-case`**: SQL CASE по user_agent, порядок важен — Edge/Opera/Android до Chrome/Safari (Chromium-UA содержат 'chrome'), Android до Linux и iOS до macOS (их UA содержат 'linux'/'mac os'). Fallback — `'Другое'`, переводится в рендере `analytics-ua-label` через `(tr :unknown)` (аналог `analytics-device-label`)
- **Rollup расширен**: INSERT в daily_stats теперь включает browser/os (из тех же CASE), `GROUP BY 1..8`, `ON CONFLICT (date, path, country, device, browser, os, referrer, is_bot)`. Старые строки daily_stats (до миграции) получают browser='Unknown'/os='Unknown' (DEFAULT) — корректно показываются как «Unknown»
- **i18n-ключи**: `:browsers :browser :os :os-name` добавлены во все 4 словаря (проверка: все `(tr :key)` из кода есть во всех 4, сейчас ~177 ключей)
- **Проверено**: `tab=all` (56 curl-строк → Unknown/Unknown, 34 браузерных → Firefox/Chrome/Linux) и `tab=people` (боты отфильтрованы и в rollup-данных), источники по-прежнему только внешние

### Аналитика — подводные камни
- **`postmodern:connected-p` требует 1 аргумент** (объект БД), не 0. Вызов без аргумента — "invalid number of arguments". То же для `postmodern:disconnect`. Аналитика не вызывает их напрямую: флаг `*db-available*` (ставится в `db-connect`) → `unless *db-available*` в `log-page-view`. `db-disconnect` обёрнут в `handler-case` (был латентный краш на `(connected-p)`)
- **Wookie не кладёт `:remote-addr` в Clack env** — клиентский IP доступен только через заголовки `X-Real-IP` / `X-Forwarded-For` (первый хоп). Без прокси `ip` в `page_views` остаётся NULL. Извлечь peer-адрес из сокета cl-async нельзя: слот `address` не заполняется, `uv_tcp_getpeername` не обёрнут в CFFI
- **Postmodern превращает Lisp NIL в SQL-строку "false"** (и `search`-позиции вроде 0 — в SQL false): для nullable TEXT-колонок передавать `:null` (функция `sql-null-if-nil`), булевы детекторы (`bot-user-agent-p`) должны возвращать строго T/NIL, иначе `googlebot` на позиции 3 упадёт в boolean-колонку
- **Postmodern возвращает SQL NULL в результатах как символ `:NULL`** — он truthy! `(or x "")` его НЕ отсекает (`(or :NULL "")` → `:NULL`), а `length`/`string-trim` на нём падают ("The value :NULL is not of type SEQUENCE"). Дашборд аналитики ловил это в "Последние визиты" (`(analytics-truncate (or referrer ""))`). **Фикс**: `COALESCE(referrer, '')` прямо в SQL (`analytics-recent`), а не в Lisp
- **Скрытый URL аналитики** (`/analytics/<secret>`): рендерит тот же `forum-page-analytics` с `user=nil` (header рендерится анонимным — ок). Добавлен 2026-08-11 (когда вход/регистрация были отключены; с 2026-08-21 авторизация снова работает, но URL оставлен как запасной вход)

## Markdown-парсер на чистом CL (JSCL) (2026-08-14)
- Цель: заменить marked.js + DOMPurify + highlight.js на чистый CL-парсер, компилируемый JSCL. Живёт в `jscl-tools/markdown.lisp` (пакет `:markdown`, экспорт `render-to-html`)
- **Подключён в site-бандл (2026-08-14)**: `build-resources.lisp` компилирует site-бандл как `(prelude markdown.lisp site.lisp)` (порядок важен: markdown ДО site, чтобы `markdown:render-to-html` резолвился). markdown.lisp исключён из `*tool-sources*` и из независимых бандлов (тот же механизм, что у site.lisp)
- **marked.js + DOMPurify УДАЛЕНЫ (2026-08-14)**: `render-markdown-to`/`md-toggle-preview` в site.lisp зовут `markdown:render-to-html` напрямую (без `marked-defined-p`/`set-markdown-options`/`sanitize-html`-обвязки — парсер сам экранирует raw HTML). CDN-скрипты `marked.min.js` и `purify.min.js` убраны из `forum-render-head` (`forum-pages.lisp`) и из `page-index` (`pages.lisp`). REPL: `repl-start` печатает кредиты строкой (`dom-append-line`), `dom-append-html` переписан на textContent (без DOMPurify-ветки)
- **Компиляция вручную**: `cp jscl-tools/markdown.lisp /tmp/md_iterN.lisp` (свежий путь — кэш JSCL по пути!) → `node --stack-size=65536 jscl/jscl-node.js /tmp/compile_mdN.lisp` (`compile-application`, `:place ""`, имя бандла `/tmp/md_iterN.js`) → тест `sed` бандла в `/tmp/mdtest2.js`/`/tmp/mdtests_full.js` (заменой `/tmp/md_iter4.js`)
- **Benign (2026-08-14)**: в конце compile-скрипта `(quit)` кидает `UNDEFINED-FUNCTION: QUIT` ПОСЛЕ записи бандла — это норма, проверять успех через `ls -la` бандла + `MD-COMPILE-OK`
- **Emphasis — переписан с нуля (2026-08-14)**: двухпроходный delimiter-stack по CommonMark. Проход 1 `find-emphasis-matches`: стек открывающих, flanking-правила (`*`: open=left-flanking, close=right-flanking; `_`: open=lf&&(!rf||before-punct), close=rf&&(!lf||after-punct); границы строки и break-токены = whitespace), для каждого closer ищется ближайший одноранговый opener, записывается `(closer . k)` (k=2 если обе досижение ≥2 иначе 1), обрезаются длины, стек выше opener удаляется, leftover дописывается обратно. `opener-matches` после прохода в хронологическом порядке (внешние раньше — `nreverse`!). Проход 2 `build-emphasis-tree`: фреймы `(opener-idx pending-matches children)` строят `:emph`/`:strong`, общий opener+closer даёт `***both***` → `em<strong>`, остатки — литерал через `literal-delim`. `find-close-delim` удалён
- **Важный баг-урок (2026-08-14)**: неправильное распределение `)` в `build-emphasis-tree` было «сбалансировано» и читалось SBCL как 66 форм, НО структура оказалась другой: `(labels ((emit ...) (loop for ...)) ...)` — `(loop ...)` уехал в список локальных функций labels как определение `(LOOP FOR J FROM ...)` → JSCL при компиляции падал `TYPE-ERROR: FOR is not a CONS` в `list-until-keyword`/`parse-lambda-list`. Правильно: `(push node (third frame)))))` — 5 закрывающих (emit из 3 вложений), `(nreverse (third root))))` — 4. Диагностика: JSCL compile ловит то, что SBCL READ не замечает — проверять структуру через `(read ...)` и печатать форму целиком (SBLC покажет `(LOOP FOR J ...)` в списке labels!). Бинсекция через под-файлы `defun` по одному
- **Мод-3 правило реализовано (2026-08-14)**: `emphasis-match-forbidden-p` + `find-opener` (сигнатура `(tokens leftover stack j)`) — если opener ИЛИ closer может и открывать, и закрывать, а `(olen+clen)%3==0` при `clen%3!=0` — пара НЕ образует эмфазу, ищем более старый opener (cmark `process_emphasis`). `*foo**bar*` → `<em>foo**bar</em>`, `*foo**bar**baz*` → `<em>foo<strong>bar</strong>baz</em>`, `***both***` → `<em><strong>both</strong></em>` — все spec Examples 410-418 PASS. Замечание: `opener-matches` после прохода в хронологическом порядке (внешний создаётся первым — `nreverse`!), порядок критичен для shared opener/closer
- **Spec-тесты**: `tests/markdown/spec-emphasis.test.js` — 132 примера из CommonMark 0.31.2 section 6.2 (парсер из HTML spec). UPDATE: PASS=132 FAIL=0 (все примеры emphasis проходят; сыро-html inline 475/476/477 — намеренное отклонение: наш парсер экранирует raw HTML вместо пропуска как CommonMark — sanitizer требует)
- **Эмфаза в label ссылок (2026-08-14)**: `[*bar*](/url)` → `<em>bar</em>`. `parse-inline-link` теперь хранит children label'а как inline-узлы через `parse-label-inline` = `(parse-emphasis (parse-inline-lex label t))`; `parse-inline-lex` получил опциональный `no-links` (в label'ах ссылки не парсятся, `[`/`!` — текст). Узел `:link` — `(:link url title . children)` (children НЕ вложенным списком, а спреднуты; иначе рендер печатал `(b a r)`), `:image` label остаётся строкой (4-й элемент)
- **`&quot;`-эскейпинг**: text-контент экранирует `"` → `&quot;` (CommonMark-совместимо; тест full `& < > "` обновлён)
- **Тест-экстракция мультистрочных примеров**: 367/384/394/405/423/432 в spec-emphasis.test.js были обрезаны на `\n` (ожидание `<p>...` без закрывающего), 354 — потеряны `</p>\n` между абзацами. Все исправлены на полные spec.json-ожидания
- **Тесты (tests/)**: `tests/markdown/run-tests.sh` — компилирует `jscl-tools/markdown.lisp` нодой (`compile.lisp`, бандл `$TMPDIR/markdown.test.bundle.js`) и прогоняет `smoke` (9), `full` (28), `edge` (5), `spec-emphasis` (132) → **PASS=174 FAIL=0** (все зелёные: ASCII+Unicode ws/punct, `&quot;`-эскейпинг, эмфаза в link text, NBSP `£`/`€`; raw HTML inline 475/476/477 — намеренное отклонение, отражено в ожиданиях теста); команда: `./tests/markdown/run-tests.sh`
### Подсветка синтаксиса Lisp на чистом CL (2026-08-15)
- **highlight.js УДАЛЁН** — подсветка синтаксиса встроена в `markdown:render-to-html` (функция `highlight-lisp` в `markdown.lisp`, экспортируется): каждая code-блок оборачивается в `<pre><code>` со спанами `<span class="hl-*">`. External CDN-скрипты (highlight.min.js/hljs, github-dark.css, no-SRI) убраны из `forum-render-head` (`forum-pages.lisp`). `highlight-pre-code` удалён из site.lisp, `render-markdown-to`/`md-toggle-preview` больше не подсвечивают пост-фактум (подсветка уже в HTML от парсера)
- **Токены**: `hl-comment` (`;`-строки и `#|...|#`-блоки), `hl-string` (`"..."` с `\\`-эскейпами), `hl-char` (`#\x`), `hl-number` (для `^(+-)?\\d` и radix `#x/#b/#o/#d`), `hl-keyword` (`:keyword`), `hl-builtin` (`*hl-builtins*` — макроформы: defun, let, when, etc.), `hl-paren` (`()` и `'`,``,` — серые). Прочие символы — как есть
- **Безопасно**: все спаны выходят из `escape-html` (raw HTML внутри строк/атомов не пробивается) — XSS-санитайзинг сохранён
- **CSS**: `.hl-*` стили в `css.lisp` (тёмная тема: comment `#6a9955` italic, string `#ce9178`, char `#d7ba7d`, number `#b5cea8`, keyword `#569cd6`, builtin `#c586c0`, paren `#808080`)
- **Тесты**: в `tests/markdown/smoke.test.js` добавлены HL-кейсы (комменты/строки/диапазоны в code-блоке). `./tests/markdown/run-tests.sh` — PASS=178 FAIL=0 (smoke 13, full 28, edge 5, spec-emphasis 132). Node-тест site-бандла `/tmp/run_site_md_built.js` — PASS (рендер md-content + XSS-эскейпинг)
- **Fix (2026-08-15)**: JSCL не поддерживает `search` с `:start2` (конец "Unknown keyword argument START2") — для поиска закрывающего `|#`/`-->` внутри `highlight-lisp`/`html-block-p`/`parse-html-tag` написан `hl-find-string` (loop + `prefix-p`). Все `(search "..." s :start2 ...)` в markdown.lisp заменены на `hl-find-string`
- **Fix (2026-08-15)**: удаление `(highlight-pre-code ...)` из `md-toggle-preview` — легко потерять закрывающую скобку `)`: в site.lisp старые CDN-скрипты, новый demote — обязательно `make build` + node-тесты (компиляция site-бандла падает с READER-EOF без явной причины, если скобки не сбалансированы)

- Таймстемп структур: `(cons :emph inner)`/`(cons :strong inner)`, `render-inline-node` гардирует символы, `*nl*` = newline, JSCL без regex

## Следующая сессия
- **Открытие регистрации (2026-08-21) — сделано**: self-hosted email+пароль без внешней авторизации; антиспам — rate limiting + HMAC токены форм + honeypot + анимированная noise-CAPTCHA + bot-UA блок + валидация + троттлинг постинга 30с (см. «Антиспам»). Протестировано curl-ом (все ветки: слепой POST, мгновенный сабмит, honeypot, неверный/верный код CAPTCHA — python-декодер SVG, bot-UA, дубликаты, валидация, брутфорс-лимиты, троттлинг). Тестовые данные из dev-БД удалены. Согласие с правилами/GDPR: чекбокс на регистрации + страница `/rules` (i18n ×4)
- **Против LLM-ботов (идея на будущее)**: proof-of-work (SHA-256 nonce в site-бандле, stateless HMAC-challenge) или email verification (нужен SMTP)
- **i18n (2026-08-12) — сделано**: 4 языка (ru/en/tr/uk), cookie `lang` + Accept-Language + суффикс домена, `/set-lang`, `/i18n.js` с клиентским словарём (`window.LISPER_DICT`), `tget`/`tget-or` в site.lisp. Словари проверены (173 ключа во всех 4 языках)
- **Markdown-парсер (2026-08-14/15) — сделано полностью**: emphasis переписан и проверен + мод-3 правило + тесты в `tests/markdown/` + чистый CL-рендер с экранированием (см. раздел выше). СДЕЛАНО (2026-08-15): highlight.js УДАЛЁН, подсветка Lisp встроена в `markdown:render-to-html` (`highlight-lisp`, см. «Подсветка синтаксиса Lisp на чистом CL»), внешних CDN-скриптов на сайте больше НЕТ. `./tests/markdown/run-tests.sh` PASS=178 FAIL=0, node-тесты site-бандла (/tmp/run_site3.js — ALL PASS, /tmp/run_site_md_built.js — ALL PASS)
- **S-Dungeon аудит (2026-08-21) — сделано**: игра полностью рабочая, AGENTS.md обновлён (был устаревший статус «не реализована»). Проверено node-харнессом: загрузка бандла + START, генерация (≥5 комнат, stairs/enemies/items), движение стрелки/WASD/`.`, бой, game-over → Enter-restart, 20× RESET-GAME без крашей
  - **Тонкость node-харнесса для игровых бандлов**: бандл заканчивается `require('jscl')` — в тесте подменять require (`m==='jscl' ? jscl : require(m)`); спецпеременные читать через `jscl.internals.symbolValue(pkg.symbols['*NAME*'])` (НЕ `.fvalue` — это у функций); CL-списки/plists — cons-структуры, НЕ JS-массивы (`Array.isArray` = false; `length`/индексация не работают — использовать CL-функции GETF/LENGTH через `packages['COMMON-LISP'].symbols[...].fvalue`); JS-truthiness на CL-значениях ненадёжен (`String(NIL-symbol)` = '[object Object]', сравнивать `.name === 'NIL'`); AudioContext-стаб должен иметь `frequency/gain.setValueAtTime/exponentialRampToValueAtTime/connect/start/stop`
- **Избавиться от node в сборке** — host-компилятор JSCL (SBCL) не компилирует наш CL с `jscl::oget`/`#j`/`jscl/ffi:jsstring` («Bad function designator» / пакет JSCL неизвестен). Чистый CL через SBCL работает. Идея: бандлы по-прежнему собирать нодой, но вынести в CI/локальный пре-шаг; либо разделить «ядро» (чистый CL, компилируется SBCL) и «обвязку» (FFI, собирается JSCL)
- **Новые языки**: добавить `src/i18n-<lang>.lisp` + `register-dict` + `(tr :key)` для всех ключей; `*languages*`/`*language-labels*` в i18n.lisp
