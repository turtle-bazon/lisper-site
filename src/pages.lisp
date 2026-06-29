(in-package :lisper)

(defparameter *awesome-categories*
  '(("AI & LLMs" "artificial-intelligence-ai-llms" "#8b5cf6")
    ("ИИ и ML" "machine-learning" "#6366f1")
    ("Базы данных" "database" "#3b82f6")
    ("Веб" "network-and-internet" "#0ea5e9")
    ("GUI" "gui" "#14b8a6")
    ("FFI" "foreign-function-interface-languages-interop" "#10b981")
    ("Параллелизм" "parallelism-and-concurrency" "#22c55e")
    ("Числа" "numerical-and-scientific" "#84cc16")
    ("Строки" "text-processing" "#eab308")
    ("Редакторы" "text-editor-resources" "#f59e0b")
    ("Тестирование" "unit-testing" "#f97316")
    ("Скриптинг" "scripting" "#ef4444")
    ("Компиляторы" "compilers-code-generators" "#ec4899")
    ("Криптография" "cryptography" "#d946ef")
    ("Аудио" "audio" "#a855f7")
    ("Графика" "graphics" "#7c3aed")
    ("Утилиты" "utilities" "#6d28d9")
    ("Инструменты" "tools-1" "#4f46e5")
    ("Обучение" "learning-and-tutorials" "#2563eb")
    ("Библиотеки" "language-libraries" "#0891b2")
    ("Расширения" "language-extensions" "#059669")
    ("Форматы данных" "data-formats" "#16a34a")
    ("Структуры данных" "data-structures" "#ca8a04")
    ("Стратегии" "game-development" "#dc2626")))

(defparameter *cliki-categories*
  '(("Начинающим" "Getting%20Started" "#f59e0b")
    ("Реализации" "Common%20Lisp%20implementation" "#ef4444")
    ("Инструменты" "Development" "#ec4899")
    ("Библиотеки" "current%20recommended%20libraries" "#d946ef")
    ("Книги" "Lisp%20books" "#a855f7")
    ("Туториалы" "Online%20tutorial" "#7c3aed")
    ("FAQ" "FAQ" "#6d28d9")
    ("Конференции" "Conference" "#4f46e5")
    ("Видео" "Lisp%20Videos" "#2563eb")
    ("Упражнения" "Exercises" "#0891b2")
    ("Документы" "Document" "#059669")
    ("Игры" "Game" "#16a34a")
    ("Веб" "Web" "#ca8a04")
    ("GUI" "GUI" "#eab308")
    ("FFI" "FFI" "#84cc16")
    ("Базы данных" "Database" "#22c55e")
    ("Сеть" "Networking" "#14b8a6")
    ("Текст" "Text" "#3b82f6")
    ("Математика" "Mathematics" "#6366f1")
    ("Музыка" "Music" "#8b5cf6")
    ("Графика" "Graphics%20library" "#ec4899")
    ("Международный" "Internationalization" "#f97316")
    ("Локализация" "Internationalization" "#ef4444")
    ("Расширения" "Language%20extension" "#d946ef")))

(defun generate-cards (categories base-url)
  (with-output-to-string (out)
    (dolist (cat categories)
      (destructuring-bind (name slug color) cat
        (format out "<a href='~a~a' class='cat-card' style='--accent: ~a'>~a</a>~%"
                base-url slug color name)))))

(defun generate-game-script-tags ()
  "Генерирует HTML script теги с CL-кодами игр для JSCL."
  (with-output-to-string (out)
    (dolist (game *game-sources*)
      (let ((name (first game))
            (source (third game)))
        (format out "<script type=\"text/lisp\" id=\"game-source-~a\" style=\"display:none\">~a</script>~%"
                name source)))))

(defun generate-tool-script-tags ()
  "Генерирует HTML script теги с CL-кодами утилит для JSCL."
  (with-output-to-string (out)
    (dolist (tool *tool-sources*)
      (let ((name (first tool))
            (source (third tool)))
        (format out "<script type=\"text/lisp\" id=\"tool-source-~a\" style=\"display:none\">~a</script>~%"
                name source)))))

(defun page-index (user)
  (cl-who:with-html-output-to-string (s nil :prologue "<!DOCTYPE html>")
    (cl-who:htm
     (:html :lang "ru"
       (:head
        (:meta :charset "utf-8")
        (:meta :name "viewport" :content "width=device-width, initial-scale=1")
        (:title "lisper.ru")
        (:link :rel "icon" :type "image/svg+xml" :href *favicon-data-uri*)
        (:script :src "https://cdnjs.cloudflare.com/ajax/libs/dompurify/3.2.4/purify.min.js"
                 :integrity "sha384-eEu5CTj3qGvu9PdJuS+YlkNi7d2XxQROAFYOr59zgObtlcux1ae1Il3u7jvdCSWu"
                 :crossorigin "anonymous")
        (:style (cl-who:str (generate-css))))
      (:body
        (:div :class "container"
        (:header
         (:div :class "site-header"
          (:div :class "header-left"
           (:a :href "/" :class "header-logo"
            (cl-who:str *logo-svg*)))
          (:nav :class "header-nav"
            (:a :href "#" :id "try-repl-btn"
            (:span :class "nav-icon" (cl-who:str "<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M12 19h8'/><path d='m4 17 6-6-6-6'/></svg>")) " Попробовать CL")
           (:a :href "tg://resolve?domain=commonlisp_ru"
            (:span :class "nav-icon" (cl-who:str "<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 240 240'><circle cx='120' cy='120' r='120' fill='#229ED9'/><path d='M81.229,128.772l14.237,39.406s1.78,3.687,3.686,3.687,30.255-29.492,30.255-29.492l31.525-60.89L81.737,118.6Z' fill='#c8daea'/><path d='M100.106,138.878l-2.733,29.046s-1.144,8.9,7.754,0,17.415-15.763,17.415-15.763' fill='#a9c6d8'/><path d='M81.486,130.178,52.2,120.636s-3.5-1.42-2.373-4.64c.232-.664.7-1.229,2.1-2.2,6.489-4.523,120.106-45.36,120.106-45.36s3.208-1.081,5.1-.362a2.766,2.766,0,0,1,1.885,2.055,9.357,9.357,0,0,1,.254,2.585c-.009.752-.1,1.449-.169,2.542-.692,11.165-21.4,94.493-21.4,94.493s-1.239,4.876-5.678,5.043A8.13,8.13,0,0,1,146.1,172.5c-8.711-7.493-38.819-27.727-45.472-32.177a1.27,1.27,0,0,1-.546-.9c-.093-.469.417-1.05.417-1.05s52.426-46.6,53.821-51.492c.108-.379-.3-.566-.848-.4-3.482,1.281-63.844,39.4-70.506,43.607A3.21,3.21,0,0,1,81.486,130.178Z' fill='#fff'/></svg>")) " Telegram")
            (:a :href "#" :id "games-nav-btn"
            (:span :class "nav-icon" (cl-who:str "<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><line x1='6' y1='12' x2='10' y2='12'/><line x1='8' y1='10' x2='8' y2='14'/><line x1='15' y1='13' x2='15.01' y2='13'/><line x1='18' y1='11' x2='18.01' y2='11'/><rect x='2' y='6' width='20' height='12' rx='2'/></svg>")) " Игры")
           (:a :href "/forum"
            (:span :class "nav-icon" (cl-who:str "<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M2.992 16.342a2 2 0 0 1 .094 1.167l-1.065 3.29a1 1 0 0 0 1.236 1.168l3.413-.998a2 2 0 0 1 1.099.092 10 10 0 1 0-4.777-4.719'/></svg>")) " Форум"))
          (:div :class "header-right"
           (if user
               (cl-who:htm
                (:a :class "header-user" :href (format nil "/user/~A" (session-username user))
                 (cl-who:str (session-username user)))
                (:a :class "header-logout" :href "/logout" "Выйти"))
               (cl-who:htm
                (:a :class "header-login" :href "/login" "Войти")
                 (:a :class "header-register" :href "/register" "Регистрация"))))))
        (:main
         (:section :class "section"
          (:h2 "Что такое Common Lisp")
          (:p "Мощный диалект Common Lisp с динамической типизацией, макросами и ANSI-стандартом. Существует с 1984 года и до сих пор активно развивается.")
          (:p "Незаменим для сложных систем, ИИ, символьных вычислений и экспериментов."))
         (:section :class "section"
           (:h2 "Почему Common Lisp")
           (:ul
            (:li "Макросы - код генерирует код")
            (:li "REPL - интерактивная разработка")
            (:li "Один диалект, стабильность десятилетиями")
            (:li "Мощная система сборки ASDF")
            (:li "Богатая экосистема Quicklisp")
            (:li "Этот сайт написан и работает на Common Lisp " (:span :class "status-site" "НАШ САЙТ"))))
         (:section :class "section"
          (:h2 "Реализации")
           (:div :class "impl-grid"
            (:a :class "impl-card" :href "https://www.sbcl.org"
             (:h3 "SBCL")
             (:p "Steel Bank Common Lisp. Самая популярная реализация. Быстрая компиляция, высокая производительность, активное развитие."))
            (:a :class "impl-card" :href "https://ccl.clozure.com"
             (:h3 "CCL")
             (:p "Clozure Common Lisp. Быстрый, зрелый. Отличная интеграция с macOS (Cocoa), поддержка Linux, FreeBSD, Windows."))
            (:a :class "impl-card" :href "https://common-lisp.net/project/ecl/"
             (:h3 "ECL")
             (:p "Embeddable Common Lisp. Может встраиваться как библиотека в C-приложения. Генерирует C-код."))
            (:a :class "impl-card" :href "https://abcl.org"
             (:h3 "ABCL")
             (:p "Armed Bear Common Lisp. Работает на JVM. Интеграция с Java-библиотеками."))
            (:a :class "impl-card" :href "https://www.lispworks.com"
             (:h3 "LispWorks")
             (:p "Коммерческая реализация с IDE. Мощные инструменты отладки и профилирования."))
            (:a :class "impl-card" :href "https://franz.com/products/allegrocl"
             (:h3 "Allegro CL")
             (:p "Коммерческая реализация от Franz Inc. Enterprise-системы и большие данные."))))
          (:section :class "section"
           (:h2 "Редакторы и IDE")
           (:h3 "Готовые сборки")
           (:p :class "section-sub" "Автономные среды разработки")
           (:ul :class "resources-list"
            (:li (:a :href "https://portacle.github.io/" "Portacle") " — Emacs + SLIME + SBCL + Quicklisp + Git. Портативная, без установки")
            (:li (:a :href "https://github.com/coalton-lang/coalton/releases/latest" "mine") " — терминальная IDE для CL и Coalton. Одна программа — всё включено " (:span :class "status-new" "NEW"))
            (:li (:a :href "https://github.com/lem-project/lem/" "Lem") " — редактор на Common Lisp, поддерживает LSP, ncurses/WebGL"))
           (:h3 "Расширения и плагины")
           (:p :class "section-sub" "Интеграция с существующими редакторами")
           (:ul :class "resources-list"
            (:li (:a :href "https://github.com/slime/slime/" "SLIME") " — классический плагин для Emacs, стандарт индустрии")
            (:li (:a :href "https://github.com/joaotavora/sly" "SLY") " — форк SLIME с расширенными функциями (sticker'ы, инспектор, macrostepper)")
            (:li (:a :href "https://github.com/kchanqvq/olive/" "OLIVE") " — расширение для VS Code на базе Swank " (:span :class "status-new" "NEW"))
            (:li (:a :href "https://marketplace.visualstudio.com/items?itemName=rheller.alive" "Alive") " — расширение для VS Code на базе LSP")
            (:li (:a :href "https://github.com/kovisoft/slimv" "Slimv") " — плагин для Vim")
            (:li (:a :href "https://github.com/vlime/vlime" "Vlime") " — плагин для Vim и Neovim")
            (:li (:a :href "https://github.com/Enerccio/SLT" "SLT") " — плагин для JetBrains (IntelliJ и др.) " (:span :class "status-experimental" "Экспериментальный"))
            (:li (:a :href "https://github.com/s-clerc/slyblime" "Slyblime") " — расширение для Sublime Text"))))
         (:section :class "section awesome-section"
          (:h2 "Экосистема")
          (:p :class "section-sub" "Фреймворки, библиотеки и инструменты из "
              (:a :href "https://awesome-cl.com" "awesome-cl"))
          (:div :class "cat-grid"
           (cl-who:str (generate-cards *awesome-categories* "https://awesome-cl.com#"))))
         (:section :class "section awesome-section"
          (:h2 "Вики")
          (:p :class "section-sub" "Ресурсы и библиотеки на "
              (:a :href "https://cliki.net" "cliki.net"))
          (:div :class "cat-grid"
           (cl-who:str (generate-cards *cliki-categories* "https://cliki.net/"))))
         (:section :class "section"
          (:h2 "Полезные ресурсы")
          (:ul :class "resources-list"
           (:li (:a :href "https://lisp-lang.org/" "lisp-lang.org") " — официальный сайт языка")
           (:li (:a :href "https://www.lispworks.com/documentation/common-lisp.html" "Common Lisp HyperSpec") " — официальная спецификация")
           (:li (:a :href "https://lispcookbook.github.io/cl-cookbook/" "Common Lisp Cookbook") " — практические рецепты")
           (:li (:a :href "https://www.quicklisp.org/beta/" "Quicklisp") " — менеджер библиотек")
           (:li (:a :href "http://quickdocs.org/" "Quickdocs") " — документация по библиотекам")
           (:li (:a :href "https://exercism.org/tracks/common-lisp" "Exercism CL Track") " — упражнения с проверкой")
           (:li (:a :href "http://www.gigamonkeys.com/book/" "Practical Common Lisp") " — книга для новичков (онлайн)")
           (:li (:a :href "http://www.paulgraham.com/onlisp.html" "On Lisp") " — продвинутые макросы от Пауэлла Грейхема")
           (:li (:a :href "https://common-lisp.net/" "common-lisp.net") " — хостинг open-source проектов")
           (:li (:a :href "https://www.reddit.com/r/Common_Lisp/" "r/Common_Lisp") " — сообщество на Reddit"))))
         (:footer
          (:p
            (:a :href "https://github.com/turtle-bazon/lisper.ru" "lisper.ru") " &copy; 2026 | GPL-3.0"))
        (:div :id "repl-overlay" :class "repl-overlay"
            (:div :class "repl-modal"
             (:div :class "repl-header"
               (:a :href "/tool-source/repl" :target "_blank" "Common Lisp REPL")
               (:button :class "repl-close" "&times;"))
             (:div :id "repl-console" :class "repl-console")))
        (:div :id "games-overlay" :class "game-overlay"
            (:div :class "game-modal"
              (:div :class "game-header"
               (:a :id "games-modal-title" :href "#" "Lisp Игры")
               (:button :class "game-close" "&times;"))
             (:div :id "games-menu" :class "games-menu"
              (:div :class "games-grid"
               (:div :class "game-card" :data-game "lisp-invaders"
                :style "--accent: #22c55e"
                (cl-who:str "<svg class='game-icon' xmlns='http://www.w3.org/2000/svg' width='48' height='48' viewBox='0 0 48 48'><rect x='8' y='8' width='8' height='8' fill='#22c55e'/><rect x='32' y='8' width='8' height='8' fill='#22c55e'/><rect x='16' y='16' width='16' height='8' fill='#22c55e'/><rect x='8' y='24' width='32' height='8' fill='#22c55e'/><rect x='12' y='32' width='4' height='8' fill='#22c55e'/><rect x='32' y='32' width='4' height='8' fill='#22c55e'/><rect x='20' y='24' width='8' height='4' fill='#0a0a0a'/></svg>")
                (:h3 "Lisp Invaders")
                (:p "Защити REPL от нашествия багов! Стреляй скобками и уничтожай вирусы."))
               (:div :class "game-card" :data-game "lambda-runner"
                :style "--accent: #f59e0b"
                (cl-who:str "<svg class='game-icon' xmlns='http://www.w3.org/2000/svg' width='48' height='48' viewBox='0 0 48 48'><text x='50%' y='55%' text-anchor='middle' dominant-baseline='middle' font-size='32' font-family='monospace' font-weight='bold' fill='#f59e0b'>\xce\xbb</text></svg>")
                (:h3 "Lambda Runner")
                (:p "Лямбда бежит через лес замыканий. Собирай карри и избегай компиляторов."))
               (:div :class "game-card" :data-game "paren-matcher"
                :style "--accent: #3b82f6"
                (cl-who:str "<svg class='game-icon' xmlns='http://www.w3.org/2000/svg' width='48' height='48' viewBox='0 0 48 48'><text x='25%' y='55%' text-anchor='middle' dominant-baseline='middle' font-size='28' font-family='monospace' font-weight='bold' fill='#3b82f6'>(</text><text x='75%' y='55%' text-anchor='middle' dominant-baseline='middle' font-size='28' font-family='monospace' font-weight='bold' fill='#3b82f6'>)</text></svg>")
                (:h3 "Paren Matcher")
                 (:p "Найди и соедини пары скобок. Тренировка балансировки S-выражений."))
               (:div :class "game-card" :data-game "s-dungeon"
                :style "--accent: #a855f7"
                (cl-who:str "<svg class='game-icon' xmlns='http://www.w3.org/2000/svg' width='48' height='48' viewBox='0 0 48 48'><rect x='8' y='8' width='32' height='32' rx='2' fill='none' stroke='#a855f7' stroke-width='2'/><rect x='12' y='12' width='8' height='8' fill='#a855f7' opacity='0.8'/><rect x='28' y='12' width='8' height='8' fill='#a855f7' opacity='0.8'/><rect x='12' y='28' width='8' height='8' fill='#a855f7' opacity='0.8'/><rect x='28' y='28' width='8' height='8' fill='#a855f7' opacity='0.8'/><rect x='20' y='20' width='8' height='8' fill='#a855f7'/><line x1='20' y1='16' x2='28' y2='16' stroke='#a855f7' stroke-width='1'/><line x1='20' y1='32' x2='28' y2='32' stroke='#a855f7' stroke-width='1'/><line x1='16' y1='20' x2='16' y2='28' stroke='#a855f7' stroke-width='1'/><line x1='32' y1='20' x2='32' y2='28' stroke='#a855f7' stroke-width='1'/></svg>")
                (:h3 "S-Expression Dungeon")
                (:p "Roguelike-подземелья из S-выражений. Баги-монстры, макросы-предметы, пермадет."))))
              (:div :id "game-play" :class "game-play" :style "display:none"
              (:button :class "game-back-btn" "&larr; Назад к играм")
              (:div :class "game-body"
               (:div :id "game-loading" :class "game-loading"
                (:div :class "game-loading-text" "Загрузка...")
                (:div :class "game-loading-bar"
                 (:div :id "game-loading-fill" :class "game-loading-fill")))
               (:canvas :id "game-canvas" :width "640" :height "480"))
              (:div :class "game-footer"
                (:span :class "game-score-label" "Очки: ")
                (:span :id "game-score" "0")
                 (:span :id "game-hint" :class "game-hint" "")))))
         ;; CL-коды игр для JSCL (скрытые script теги — ВНЕ overlay)
         (cl-who:str (generate-game-script-tags))
         ;; CL-коды утилит для JSCL (скрытые script теги)
         (cl-who:str (generate-tool-script-tags))
         (:script :src "/js?v=8"))))))
