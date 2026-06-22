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
       (:style (cl-who:str (generate-css))))
      (:body
        (:div :class "container"
         (:header
          (:div :class "logo-container"
           (cl-who:str "<svg viewBox='0 0 512 512' xmlns='http://www.w3.org/2000/svg' width='80' height='80'><circle cx='256' cy='256' r='235' fill='#1a1a2e'/><path stroke='#7c3aed' stroke-width='5' fill='none' d='m255.56 20.008c-62.374 0.1169-122.17 24.922-166.3 68.992-92.236 92.091-92.353 241.52-0.2617 333.75 92.09 92.236 241.52 92.353 333.75 0.262 92.236-92.091 92.353-241.52 0.262-333.75-44.377-44.447-104.64-69.371-167.45-69.254zm2.281 1.0059c59.934 0.4846 119.39 23.809 164.46 68.953 91.701 91.845 91.585 240.64-0.259 332.34-45.922 45.851-120.32 45.793-166.17-0.129-45.851-45.922-45.793-120.32 0.129-166.17 46.412-46.339 46.471-121.53 0.13-167.94-37.084-37.141-94.457-46.553-140.66-21.658 42.416-31.541 92.711-45.798 142.37-45.396zm-190.84 130.26h40c9.943 42.147 25.204 79.418 40.75 116.43 15.9-41.326 33.203-81.249 55.25-116.43h40c-48.928 97.364-102.19 164.06-24 250h-40c-47.567-77.243-82.439-147.67-112-250z'/><path fill='#7c3aed' d='m293 110.72c78.194 85.936 24.928 152.64-24 250h40c22.047-35.179 39.35-75.102 55.25-116.43 15.546 37.01 30.807 74.282 40.75 116.43h40c-29.561-102.33-64.433-172.76-112-250z'/></svg>"))
          (:h1 "Common Lisp - язык для тех, кто думает")
          (:a :class "telegram-link" :href "https://t.me/commonlisp_ru" "Telegram"))
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
           (:li "Богатая экосистема Quicklisp")))
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
        (:p "lisper.ru &copy; 2026 | GPL-3.0")))))))
