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

(defun page-index ()
  (cl-who:with-html-output-to-string (s nil :prologue "<!DOCTYPE html>")
    (cl-who:htm
     (:html :lang "ru"
       (:head
        (:meta :charset "utf-8")
        (:meta :name "viewport" :content "width=device-width, initial-scale=1")
        (:title "lisper.ru")
        (:link :rel "icon" :type "image/svg+xml" :href *favicon-data-uri*)
        (:style (cl-who:str (generate-css))))
      (:body
        (:div :class "container"
         (:header
          (:div :class "logo-container"
           (cl-who:str *logo-svg*))
            (:h1 "Common Lisp - язык для тех, кто думает")
            (:div :class "header-buttons"
             (:a :class "try-button" :href "javascript:void(0)" :onclick "openRepl()" "Попробовать CL")
             (:a :class "telegram-link" :href "https://t.me/commonlisp_ru" "Telegram")))
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
             (:span "Common Lisp REPL")
             (:button :class "repl-close" "&times;"))
            (:div :id "repl-console" :class "repl-console")))
        (:script :src "/js?v=2"))))))



