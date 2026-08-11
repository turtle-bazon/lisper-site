# lisper — AGENTS.md

> **Правило**: при каждом изменении кода, обнаруженном баге, принятом решении или 새로운 тонкости — немедленно обновлять этот файл. AGENTS.md — живая документация проекта.

> **Ошибки**: НИКОГДА не подавлять ошибки молча. `(handler-case ... (error (e) nil))` запрещён. Всегда логировать через `console.log`. Молчание скрывает баги и ломает отладку.

> **Скриншоты**: когда пользователь говорит "посмотри скрин" — открывать файл `/tmp/screen.png`.

> **Скриншоты**: когда пользователь говорит "посмотри скриншот" — открывать файл `/tmp/screen.png`.

> **Таймауты**: максимальный таймаут для команд — 30000 мс (30 секунд).

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

## Конфигурация
- S-expression `.conf` файл (host port и т.д.)
- Шаблон: `lisper.conf.template`
- **Порт по умолчанию**: 8080
- `:geo-db-path` — путь к `GeoLite2-Country.mmdb` (MaxMind DB); если нет/не найден — гео отключено, не фатально
- `:admin-secret` — секрет скрытого URL аналитики: `/analytics/<secret>` отдаёт дашборд без логина (вход/регистрация на сайте отключены); неверный секрет → 404, `/admin/*` по-прежнему только по admin-сессии

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
- **XSS через marked.js**: `marked.parse()` без санитизации → добавлен DOMPurify (`DOMPurify.sanitize()`)
- **XSS через appendHTML()**: `div.innerHTML = html` → санитизация через DOMPurify, fallback на strip tags
- **SRI**: все CDN-скрипты (marked, highlight.js, DOMPurify) и CSS имеют `integrity` + `crossorigin="anonymous"`
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
build-resources.lisp — генерация src/resources.lisp из resources/
lisper.conf.template
License.txt         — GPL-3.0
resources/
  logo.svg          — лого Common Lisp (фиолетовые цвета)
  favicon.svg       — favicon
src/
  package.lisp      — пакет :lisper
  config.lisp       — чтение .conf файлов
  resources.lisp    — загруженные ресурсы (генерируется build-resources.lisp)
  migrations.lisp   — встроенные SQL-миграции (генерируется из migrations/)
  db.lisp           — PostgreSQL + миграции
  auth.lisp         — регистрация, логин, сессии
  forum.lisp        — CRUD операции форума
  analytics.lisp    — аналитика: page_views, geo (cl-maxminddb mmap), уникальные посетители
  forum-pages.lisp  — HTML страницы форума
  css.lisp          — CL-CSS + raw media query
  js.lisp           — plain JS string
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
- JS в `js.lisp`: `openRepl()` (инициализация), `closeRepl()`, `loadScript()`, `evalToolSource()`, `setupErrorHandler()`, markdown-редактор, игры. Все REPL-логика в CL.
- `<script src='/js'>` в `pages.lisp` после overlay (HTML-порядок: body → overlay → script)
- **Кеш jscl.js (2026-08-11)**: `/jscl.js` отдаётся с `Cache-Control: public, max-age=31536000, immutable` (2.4MB, меняется только при обновлении JSCL). URL версионируется автогенерируемым SHA-256 контента: `(jscl-url)` → `/jscl.js?v=<hash>`; хеш стабилен между сборками при неизменном бандле. Используется в `pages.lisp` (`<script src=...>`) и в `js.lisp` (`loadScript`). Хелперы `jscl-url`/`jscl-cache-key`/`string-replace-all` — в начале `js.lisp` (не в генерируемом `resources.lisp`)
- **Скомпилированные бандлы (2026-08-11)**: `jscl-tools/*.lisp` и `jscl-games/*.lisp` компилируются в JS НОДОЙ при `make build` (`build-jscl-bundles` в `build-resources.lisp`) → `src/jscl-bundles.lisp` (`*jscl-bundles*` — alist имя→JS, `get-jscl-bundle`). Отдаются на `/jscl-bundle/<name>` с `Cache-Control: public, max-age=31536000, immutable`; версионированный URL — `(jscl-bundle-url name)` → `/jscl-bundle/<name>?v=<sha256>` (хеш мемоизирован в `*jscl-bundle-cache-keys*`). Без node — пустая таблица + warning, билд не падает
- **Загрузчик переключён на бандлы (2026-08-11)**: `generate-js` вшивает карту `bundleUrls` (`name → /jscl-bundle/<name>?v=<hash>`) в `/js`. REPL при открытии грузит `bundleUrls['repl']` как `<script>` и зовёт `(repl-start)`; игры — `bundleUrls[name]` → `startCompiledGame(name)` (вызов `(name:start-name)` + `jscl.packages[PKG].symbols['GAME-LOOP-RAW'].fvalue()` в rAF-цикле). Raw-компиляция в браузере (`evalToolSource`/`evalGameSource`) осталась как fallback, если бандла нет (сборка без node). Бандл сам находит runtime: `typeof require !== 'undefined' ? require('jscl') : window.jscl : self.jscl`; jscl.js ставит `self.jscl` (в браузере `self===window`). Вендоренный jscl.js (в `jscl/`) умеет `module.exports` — проверено в node: бандлы регистрируют пакеты и функции (LISP-INVADERS с START-LISP-INVADERS/GAME-LOOP-RAW, REPL-START fbound из CL-USER)
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

### Антиспам
- **Honeypot CAPTCHA** на регистрации — скрытое поле `website`, боты его заполняют, humans нет
- **Закрытие форума** — флаг `forum_closed` в таблице `settings`, админ может закрыть/открыть через `/admin/toggle-forum`
- Когда форум закрыт: обычные пользователи не могут создавать топики/посты, админы могут
- Статус форума виден в админке: "ОТКРЫТ" (зелёный) / "ЗАКРЫТ" (красный) + кнопка toggle

### Аудит
- Таблица `audit_log` (id, user_id, action, target_type, target_id, details, created_at)
- Функция `log-audit` в `forum.lisp` — логирует все действия модерации
- Действия: delete-post, delete-topic, mute-user, unmute-user, set-role, toggle-forum
- Вызывается из handlers в `routes.lisp` после каждого действия

### Редактор постов
- **Markdown** — посты хранятся как raw markdown, рендерятся клиентски через marked.js
- **Подсветка кода** — highlight.js с поддержкой Common Lisp и других языков
- **Тулбар** — жирный, курсив, заголовки, списки, цитаты, код, ссылки, картинки, превью
- **Превью** — кнопка 👁 переключает между редактированием и предпросмотром
- **Компонент**: `forum-render-editor` — переиспользуемый для new-topic и reply
- **Клиентский рендеринг**: `.md-content` класс инициализируется marked.js при загрузке страницы

## Отчёт по безопасности (24.06.2026)
Полный отчёт в `/tmp/report.txt`. Исправлено:
1. **Stored XSS через marked.js** → DOMPurify санитизация
2. **XSS через appendHTML()** → DOMPurify санитизация, fallback strip tags
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
- **S-Expression Dungeon** (планируется) — roguelike с картами из S-выражений:
  - Комната = `(room (enemies defun lambda) (items macro-quote) (doors left right))`
  - Герой — интерпретатор, враги — баги (void-function, wrong-type-argument), лут — макросы
  - Пошаговый, тайл-based, minimap, пермадет, прогрессия
  - Пока не реализовано — после доделки Lisp Invaders
- **Порт**: 8080

## Аналитика (2026-08)
- Своя серверная аналитика в PostgreSQL: таблица `page_views` (id, visitor_id, path, referrer, user_agent, ip, country, is_bot, created_at). Гео — НЕ в БД, см. ниже
- Миграции: **0005** (`page_views`), **0006** (drop `ip_country`), **0007** (`daily_stats`)
- **Безопасность хранения (ретеншен, 2026-08-11)**: сырые `page_views` живут `*analytics-raw-retention-days*` = 7 дней (окно дашборда), потом сворачиваются в `daily_stats` и удаляются. Рост ограничен: ~7 дней сырых + ~1-2k строк агрегатов/день
  - `daily_stats (date, path, country, device, referrer, is_bot, views)` — аддитивно по всем измерениям, PK по всем колонкам кроме views. «OLAP для бедных»
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
- **Дашборд**: `/admin/analytics` (только admin): stat-карточки (всего/24ч/7д просмотры + уникальные + боты), топ страниц, источники, страны (если mmdb загружен), устройства (mobile/desktop), последние 30 визитов
- Бот-фильтр: агрегаты включают ботов (страны/устройства/источники), есть отдельная карточка «Боты»
- **Перф**: INSERT на каждый просмотр страницы; индексы (created_at, visitor_id, path)

### Аналитика — подводные камни
- **`postmodern:connected-p` требует 1 аргумент** (объект БД), не 0. Вызов без аргумента — "invalid number of arguments". То же для `postmodern:disconnect`. Аналитика не вызывает их напрямую: флаг `*db-available*` (ставится в `db-connect`) → `unless *db-available*` в `log-page-view`. `db-disconnect` обёрнут в `handler-case` (был латентный краш на `(connected-p)`)
- **Wookie не кладёт `:remote-addr` в Clack env** — клиентский IP доступен только через заголовки `X-Real-IP` / `X-Forwarded-For` (первый хоп). Без прокси `ip` в `page_views` остаётся NULL. Извлечь peer-адрес из сокета cl-async нельзя: слот `address` не заполняется, `uv_tcp_getpeername` не обёрнут в CFFI
- **Postmodern превращает Lisp NIL в SQL-строку "false"** (и `search`-позиции вроде 0 — в SQL false): для nullable TEXT-колонок передавать `:null` (функция `sql-null-if-nil`), булевы детекторы (`bot-user-agent-p`) должны возвращать строго T/NIL, иначе `googlebot` на позиции 3 упадёт в boolean-колонку
- **Postmodern возвращает SQL NULL в результатах как символ `:NULL`** — он truthy! `(or x "")` его НЕ отсекает (`(or :NULL "")` → `:NULL`), а `length`/`string-trim` на нём падают ("The value :NULL is not of type SEQUENCE"). Дашборд аналитики ловил это в "Последние визиты" (`(analytics-truncate (or referrer ""))`). **Фикс**: `COALESCE(referrer, '')` прямо в SQL (`analytics-recent`), а не в Lisp
- **Скрытый URL аналитики** (`/analytics/<secret>`): рендерит тот же `forum-page-analytics` с `user=nil` (header рендерится анонимным — ок). Добавлен 2026-08-11; до этого дашборд невозможно было открыть, т.к. вход/регистрация отключены

## Следующая сессия
- **Autoloading jscl** — загружать jscl.js при старте страницы, а не при первом открытии REPL/игры
- **Избавиться от node в сборке** — host-компилятор JSCL (SBCL) не компилирует наш CL с `jscl::oget`/`#j`/`jscl/ffi:jsstring` («Bad function designator» / пакет JSCL неизвестен). Чистый CL через SBCL работает. Идея: бандлы по-прежнему собирать нодой, но вынести в CI/локальный пре-шаг; либо разделить «ядро» (чистый CL, компилируется SBCL) и «обвязку» (FFI, собирается JSCL)
