# lisper.ru — AGENTS.md

> **Правило**: при каждом изменении кода, обнаруженном баге, принятом решении или 새로운 тонкости — немедленно обновлять этот файл. AGENTS.md — живая документация проекта.

> **Скриншоты**: когда пользователь говорит "посмотри скриншот" — открывать файл `/tmp/screen.png`.

> **Таймауты**: максимальный таймаут для команд — 30000 мс (30 секунд).

## О проекте
Сайт lisper.ru — лендинг о Common Lisp. Всё на Lisp: HTML, CSS, JS.

## Стек
- **Сервер**: Clack + Wookie (`clack-handler-wookie`) `:debug nil`
- **HTML**: CL-WHO (`with-html-output-to-string` + `htm`)
- **CSS**: CL-CSS (`cl-css:css`)
- **JS**: plain string (Parenscript убран из-за конфликта readtable)
- **БД**: PostgreSQL 15 через `postmodern` (user=lisper, pass=lisper, db=lisper, host=127.0.0.1)
- **Аутентификация**: ironclad PBKDF2 (SHA-256, 100k iter), cookie-based sessions (30 дней)
- **Миграции**: SQL-файлы `migrations/NNNN-name.{up,down}.sql`, встроены в бинарник через `src/migrations.lisp`, таблица `schema_migrations`
- **Бинарник**: buildapp → `build/lisper` (~93MB)
- **Лицензия**: GPL-3.0
- **Исходники**: https://github.com/turtle-bazon/lisper.ru (зеркало, основная СКВ — Mercurial)

## Конфигурация
- S-expression `.conf` файл (host port и т.д.)
- Шаблон: `lisper.conf.template`

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
- Бинарник: `make` → `build/lisper` (~57MB)

### Безопасность
- **XSS через marked.js**: `marked.parse()` без санитизации → добавлен DOMPurify (`DOMPurify.sanitize()`)
- **XSS через appendHTML()**: `div.innerHTML = html` → санитизация через DOMPurify, fallback на strip tags
- **SRI**: все CDN-скрипты (marked, highlight.js, DOMPurify) и CSS имеют `integrity` + `crossorigin="anonymous"`
- **Security Headers**: CSP, X-Frame-Options: DENY, X-Content-Type-Options: nosniff, Referrer-Policy, X-XSS-Protection: 0
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
  forum-pages.lisp  — HTML страницы форума
  css.lisp          — CL-CSS + raw media query
  js.lisp           — plain JS string
  pages.lisp        — CL-WHO HTML (cat-card генерация)
  routes.lisp       — роутинг через path-info
  main.lisp         — entry point
```

## Секции на главной
1. **Header** — лого (ссылка на `/`) + навигация (Попробовать CL, Telegram, Форум) + учётка справа (Войти/Регистрация или имя+Выйти)
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
- Ленивая загрузка: jquery.js → jqconsole.js → jscl.js → jscl-web.js
- `(exit)` / `(quit)` / `(si:quit)` закрывают модалку
- Escape тоже закрывает модалку
- **Custom terminal REPL** (не jqconsole) — свой input-элемент + appendLine/appendHTML
- Модалка: `.repl-overlay` → `.repl-modal` → `.repl-console` (div с `.repl-line` children)
- Стили в `css.lisp`: `.try-button` (зелёный), `.repl-overlay`, `.repl-modal`, `.repl-console`, `.repl-header`, `.repl-input`, `.repl-prompt-label`
- JS в `js.lisp`: `openRepl()`, `closeRepl()`, `createInputLine()`, `submitInput()`, `appendLine()`, `appendHTML()`
- `<script src='/js'>` в `pages.lisp` после overlay (HTML-порядок: body → overlay → script)
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
- При добавлении новой миграции: создать SQL-файлы, добавить в `*migrations*` в `src/migrations.lisp`

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
