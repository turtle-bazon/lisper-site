# lisper.ru — AGENTS.md

> **Правило**: при каждом изменении кода, обнаруженном баге, принятом решении или 새로운 тонкости — немедленно обновлять этот файл. AGENTS.md — живая документация проекта.

## О проекте
Сайт lisper.ru — лендинг о Common Lisp. Всё на Lisp: HTML, CSS, JS.

## Стек
- **Сервер**: Clack + Wookie (`clack-handler-wookie`) `:debug nil`
- **HTML**: CL-WHO (`with-html-output-to-string` + `htm`)
- **CSS**: CL-CSS (`cl-css:css`)
- **JS**: plain string (Parenscript убран из-за конфликта readtable)
- **БД**: PostgreSQL 15 через `postmodern` (user=lisper, pass=lisper, db=lisper, host=127.0.0.1)
- **Аутентификация**: ironclad PBKDF2 (SHA-256, 100k iter), cookie-based sessions (30 дней)
- **Миграции**: SQL-файлы `migrations/NNNN-name.{up,down}.sql`, таблица `schema_migrations`
- **Бинарник**: buildapp → `build/lisper` (~93MB)
- **Лицензия**: GPL-3.0
- **Исходники**: https://github.com/turtle-bazon/lisper.ru

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
1. Заголовок "Common Lisp - язык для тех, кто думает" + лого + Telegram + **"Попробовать CL"** (JSCL REPL)
2. Что такое Common Lisp
3. Почему Common Lisp
4. **Реализации** — 6 карточек (SBCL, CCL, ECL, ABCL, LispWorks, Allegro CL)
5. **Редакторы и IDE** — две подсекции: "Готовые сборки" (Portacle, mine [NEW], Lem) и "Расширения и плагины" (SLIME, SLY, OLIVE [NEW], Alive, Slimv, Vlime, SLT [Экспериментальный], Slyblime)
6. **Экосистема** — 24 карточки awesome-cl.com (генерируются из `*awesome-categories*`)
7. **Вики** — 24 карточки cliki.net (генерируются из `*cliki-categories*`)
8. **Полезные ресурсы** — список ссылок (lisp-lang.org, HyperSpec, Cookbook, Quicklisp, Quickdocs, Exercism, Practical CL, On Lisp, common-lisp.net, Reddit)
9. Footer (ссылка на GitHub)
10. **REPL-модалка** — всплывающее окно с JSCL (Common Lisp в браузере)

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

## Форум
- **Страницы**: `/forum`, `/forum/{slug}`, `/topic/{id}`, `/new-topic`, `/login`, `/register`, `/logout`
- **POST-роуты**: `/login`, `/register`, `/new-topic`, `/new-post`, `/delete-post`
- **POST-body**: `parse-post-body` читает `raw-body` stream → URL-decode → hash-table
- **Категории**: 4 (Общее, Проекты, Помощь, Новости) — seed в миграции 0001
- **Роли**: user, moderator, admin (поле `role` в `users`)
- **Сессии**: cookie `session=HEX`, таблица `sessions`, TTL 30 дней

### Auth
- `hash-password` → `ironclad:pbkdf2-hash-password` (SHA-256, 100k iter), формат `HEX_SALT:HEX_KEY`
- `verify-password` → `pbkdf2-hash-password` с `:salt`, `equalp` сравнение
- `register-user` → INSERT + `cl-postgres:database-error` при уникальности
- `authenticate-user` → SELECT + verify → `create-user-session`
- `current-user` → `extract-session-token` (из `(getf env :headers)` hash-table) → `get-user-by-session`
- **Важно**: `(getf env :headers)` — это hash-table, не строка; искать через `(gethash "cookie" headers)`

### Миграции
- Формат: `migrations/0001-name.up.sql` / `0001-name.down.sql` (4-значный номер)
- Таблица `schema_migrations`: version (int PK), name, applied_at
- `get-available-migrations` — `(position #\.` (первый dot) для имени файла
- `read-migration-file` — `make-array` с fill-pointer для UTF-8
- `apply-migration` — split SQL by `;` + execute each via `postmodern:query` (не multi-statement)
