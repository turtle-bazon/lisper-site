(in-package :lisper)

(defparameter *awesome-categories*
  '((:cat-ai "artificial-intelligence-ai-llms" "#8b5cf6")
    (:cat-ml "machine-learning" "#6366f1")
    (:cat-db "database" "#3b82f6")
    (:cat-web "network-and-internet" "#0ea5e9")
    (:cat-gui "gui" "#14b8a6")
    (:cat-ffi "foreign-function-interface-languages-interop" "#10b981")
    (:cat-parallel "parallelism-and-concurrency" "#22c55e")
    (:cat-numerical "numerical-and-scientific" "#84cc16")
    (:cat-text "text-processing" "#eab308")
    (:cat-editors "text-editor-resources" "#f59e0b")
    (:cat-testing "unit-testing" "#f97316")
    (:cat-scripting "scripting" "#ef4444")
    (:cat-compilers "compilers-code-generators" "#ec4899")
    (:cat-crypto "cryptography" "#d946ef")
    (:cat-audio "audio" "#a855f7")
    (:cat-graphics "graphics" "#7c3aed")
    (:cat-utilities "utilities" "#6d28d9")
    (:cat-tools "tools-1" "#4f46e5")
    (:cat-learning "learning-and-tutorials" "#2563eb")
    (:cat-libraries "language-libraries" "#0891b2")
    (:cat-extensions "language-extensions" "#059669")
    (:cat-formats "data-formats" "#16a34a")
    (:cat-data-structures "data-structures" "#ca8a04")
    (:cat-strategy "game-development" "#dc2626")))

(defparameter *cliki-categories*
  '((:cliki-start "Getting%20Started" "#f59e0b")
    (:cliki-impl "Common%20Lisp%20implementation" "#ef4444")
    (:cliki-tools "Development" "#ec4899")
    (:cliki-libraries "current%20recommended%20libraries" "#d946ef")
    (:cliki-books "Lisp%20books" "#a855f7")
    (:cliki-tutorials "Online%20tutorial" "#7c3aed")
    (:cliki-faq "FAQ" "#6d28d9")
    (:cliki-conferences "Conference" "#4f46e5")
    (:cliki-video "Lisp%20Videos" "#2563eb")
    (:cliki-exercises "Exercises" "#0891b2")
    (:cliki-documents "Document" "#059669")
    (:cliki-games "Game" "#16a34a")
    (:cliki-web "Web" "#ca8a04")
    (:cliki-gui "GUI" "#eab308")
    (:cliki-ffi "FFI" "#84cc16")
    (:cliki-db "Database" "#22c55e")
    (:cliki-networking "Networking" "#14b8a6")
    (:cliki-text "Text" "#3b82f6")
    (:cliki-math "Mathematics" "#6366f1")
    (:cliki-music "Music" "#8b5cf6")
    (:cliki-graphics "Graphics%20library" "#ec4899")
    (:cliki-intl "Internationalization" "#f97316")
    (:cliki-l10n "Internationalization" "#ef4444")
    (:cliki-extensions "Language%20extension" "#d946ef")))

(defun generate-cards (categories base-url)
  (with-output-to-string (out)
    (dolist (cat categories)
      (destructuring-bind (key slug color) cat
        (format out "<a href='~a~a' class='cat-card' style='--accent: ~a'>~a</a>~%"
                base-url slug color (tr key))))))

(defun page-index (user)
  (cl-who:with-html-output-to-string (s nil :prologue "<!DOCTYPE html>")
    (cl-who:htm
     (:html :lang *lang*
       (:head
        (:meta :charset "utf-8")
        (:meta :name "viewport" :content "width=device-width, initial-scale=1")
        (:title "lisper")
        (:link :rel "icon" :type "image/svg+xml" :href *favicon-data-uri*)
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
            (:span :class "nav-icon" (cl-who:str "<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M12 19h8'/><path d='m4 17 6-6-6-6'/></svg>")) (cl-who:str (tr :nav-try)))
            (:a :href "tg://resolve?domain=commonlisp_ru"
            (:span :class "nav-icon" (cl-who:str "<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 240 240'><circle cx='120' cy='120' r='120' fill='#229ED9'/><path d='M81.229,128.772l14.237,39.406s1.78,3.687,3.686,3.687,30.255-29.492,30.255-29.492l31.525-60.89L81.737,118.6Z' fill='#c8daea'/><path d='M100.106,138.878l-2.733,29.046s-1.144,8.9,7.754,0,17.415-15.763,17.415-15.763' fill='#a9c6d8'/><path d='M81.486,130.178,52.2,120.636s-3.5-1.42-2.373-4.64c.232-.664.7-1.229,2.1-2.2,6.489-4.523,120.106-45.36,120.106-45.36s3.208-1.081,5.1-.362a2.766,2.766,0,0,1,1.885,2.055,9.357,9.357,0,0,1,.254,2.585c-.009.752-.1,1.449-.169,2.542-.692,11.165-21.4,94.493-21.4,94.493s-1.239,4.876-5.678,5.043A8.13,8.13,0,0,1,146.1,172.5c-8.711-7.493-38.819-27.727-45.472-32.177a1.27,1.27,0,0,1-.546-.9c-.093-.469.417-1.05.417-1.05s52.426-46.6,53.821-51.492c.108-.379-.3-.566-.848-.4-3.482,1.281-63.844,39.4-70.506,43.607A3.21,3.21,0,0,1,81.486,130.178Z' fill='#fff'/></svg>")) (cl-who:str (tr :nav-telegram)))
            (:a :href "#" :id "games-nav-btn"
            (:span :class "nav-icon" (cl-who:str "<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><line x1='6' y1='12' x2='10' y2='12'/><line x1='8' y1='10' x2='8' y2='14'/><line x1='15' y1='13' x2='15.01' y2='13'/><line x1='18' y1='11' x2='18.01' y2='11'/><rect x='2' y='6' width='20' height='12' rx='2'/></svg>")) (cl-who:str (tr :nav-games)))
           (:a :href "/forum"
            (:span :class "nav-icon" (cl-who:str "<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M2.992 16.342a2 2 0 0 1 .094 1.167l-1.065 3.29a1 1 0 0 0 1.236 1.168l3.413-.998a2 2 0 0 1 1.099.092 10 10 0 1 0-4.777-4.719'/></svg>")) (cl-who:str (tr :nav-forum))))
          (:div :class "header-right"
           (cl-who:str (render-lang-switch))
           (if user
               (cl-who:htm
                (:a :class "header-user" :href (format nil "/user/~A" (session-username user))
                 (cl-who:str (session-username user)))
                (:a :class "header-logout" :href "/logout" (cl-who:str (tr :logout))))
               (cl-who:htm
                (:a :class "header-login" :href "/login" (cl-who:str (tr :login)))
                 (:a :class "header-register" :href "/register" (cl-who:str (tr :register))))))))
        (:main
         (:section :class "section"
          (:h2 (cl-who:str (tr :what)))
          (:p (cl-who:str (tr :what-p1)))
          (:p (cl-who:str (tr :what-p2))))
         (:section :class "section"
           (:h2 (cl-who:str (tr :why)))
           (:ul
            (:li (cl-who:str (tr :why-macros)))
            (:li (cl-who:str (tr :why-repl)))
            (:li (cl-who:str (tr :why-stability)))
            (:li (cl-who:str (tr :why-asdf)))
            (:li (cl-who:str (tr :why-quicklisp)))
            (:li (cl-who:str (tr :why-site)) (:span :class "status-site" (cl-who:str (tr :badge-site))))))
         (:section :class "section"
          (:h2 (cl-who:str (tr :impl)))
           (:div :class "impl-grid"
            (:a :class "impl-card" :href "https://www.sbcl.org"
             (:h3 "SBCL")
             (:p (cl-who:str (tr :impl-sbcl))))
            (:a :class "impl-card" :href "https://ccl.clozure.com"
             (:h3 "CCL")
             (:p (cl-who:str (tr :impl-ccl))))
            (:a :class "impl-card" :href "https://common-lisp.net/project/ecl/"
             (:h3 "ECL")
             (:p (cl-who:str (tr :impl-ecl))))
            (:a :class "impl-card" :href "https://abcl.org"
             (:h3 "ABCL")
             (:p (cl-who:str (tr :impl-abcl))))
            (:a :class "impl-card" :href "https://www.lispworks.com"
             (:h3 "LispWorks")
             (:p (cl-who:str (tr :impl-lispworks))))
            (:a :class "impl-card" :href "https://franz.com/products/allegrocl"
             (:h3 "Allegro CL")
             (:p (cl-who:str (tr :impl-allegro))))))
          (:section :class "section"
           (:h2 (cl-who:str (tr :editors)))
           (:h3 (cl-who:str (tr :editors-builds)))
           (:p :class "section-sub" (cl-who:str (tr :editors-builds-sub)))
           (:ul :class "resources-list"
            (:li (:a :href "https://portacle.github.io/" "Portacle") (cl-who:str (tr :res-portacle)))
            (:li (:a :href "https://github.com/coalton-lang/coalton/releases/latest" "mine") (cl-who:str (tr :res-mine)) (:span :class "status-new" (cl-who:str (tr :badge-new))))
            (:li (:a :href "https://github.com/lem-project/lem/" "Lem") (cl-who:str (tr :res-lem))))
           (:h3 (cl-who:str (tr :editors-plugins)))
           (:p :class "section-sub" (cl-who:str (tr :editors-plugins-sub)))
           (:ul :class "resources-list"
            (:li (:a :href "https://github.com/slime/slime/" "SLIME") (cl-who:str (tr :res-slime)))
            (:li (:a :href "https://github.com/joaotavora/sly" "SLY") (cl-who:str (tr :res-sly)))
            (:li (:a :href "https://github.com/kchanqvq/olive/" "OLIVE") (cl-who:str (tr :res-olive)) (:span :class "status-new" (cl-who:str (tr :badge-new))))
            (:li (:a :href "https://marketplace.visualstudio.com/items?itemName=rheller.alive" "Alive") (cl-who:str (tr :res-alive)))
            (:li (:a :href "https://github.com/kovisoft/slimv" "Slimv") (cl-who:str (tr :res-slimv)))
            (:li (:a :href "https://github.com/vlime/vlime" "Vlime") (cl-who:str (tr :res-vlime)))
            (:li (:a :href "https://github.com/Enerccio/SLT" "SLT") (cl-who:str (tr :res-slt)) (:span :class "status-experimental" (cl-who:str (tr :badge-experimental))))
            (:li (:a :href "https://github.com/s-clerc/slyblime" "Slyblime") (cl-who:str (tr :res-slyblime))))))
         (:section :class "section awesome-section"
          (:h2 (cl-who:str (tr :ecosystem)))
          (:p :class "section-sub" (cl-who:str (tr :ecosystem-sub))
              (:a :href "https://awesome-cl.com" "awesome-cl"))
          (:div :class "cat-grid"
           (cl-who:str (generate-cards *awesome-categories* "https://awesome-cl.com#"))))
         (:section :class "section awesome-section"
          (:h2 (cl-who:str (tr :wiki)))
          (:p :class "section-sub" (cl-who:str (tr :wiki-sub))
              (:a :href "https://cliki.net" "cliki.net"))
          (:div :class "cat-grid"
           (cl-who:str (generate-cards *cliki-categories* "https://cliki.net/"))))
         (:section :class "section"
          (:h2 (cl-who:str (tr :resources)))
          (:ul :class "resources-list"
           (:li (:a :href "https://lisp-lang.org/" "lisp-lang.org") (cl-who:str (tr :res-lisp-lang)))
           (:li (:a :href "https://www.lispworks.com/documentation/common-lisp.html" "Common Lisp HyperSpec") (cl-who:str (tr :res-hyperspec)))
           (:li (:a :href "https://lispcookbook.github.io/cl-cookbook/" "Common Lisp Cookbook") (cl-who:str (tr :res-cookbook)))
           (:li (:a :href "https://www.quicklisp.org/beta/" "Quicklisp") (cl-who:str (tr :res-quicklisp)))
           (:li (:a :href "http://quickdocs.org/" "Quickdocs") (cl-who:str (tr :res-quickdocs)))
           (:li (:a :href "https://exercism.org/tracks/common-lisp" "Exercism CL Track") (cl-who:str (tr :res-exercism)))
           (:li (:a :href "http://www.gigamonkeys.com/book/" "Practical Common Lisp") (cl-who:str (tr :res-pcl)))
           (:li (:a :href "http://www.paulgraham.com/onlisp.html" "On Lisp") (cl-who:str (tr :res-onlisp)))
           (:li (:a :href "https://common-lisp.net/" "common-lisp.net") (cl-who:str (tr :res-clnet)))
           (:li (:a :href "https://www.reddit.com/r/Common_Lisp/" "r/Common_Lisp") (cl-who:str (tr :res-reddit))))))
         (:footer
          (:p
            (:a :href "https://github.com/turtle-bazon/lisper-site" "lisper") " &copy; 2026 | GPL-3.0"))
        (:div :id "repl-overlay" :class "repl-overlay"
            (:div :class "repl-modal"
             (:div :class "repl-header"
               (:a :href "/tool-source/repl" :target "_blank" "Common Lisp REPL")
               (:button :class "repl-close" "&times;"))
             (:div :id "repl-console" :class "repl-console")))
        (:div :id "games-overlay" :class "game-overlay"
            (:div :class "game-modal"
              (:div :class "game-header"
               (:a :id "games-modal-title" :href "#" (cl-who:str (tr :games-title)))
               (:button :class "game-close" "&times;"))
             (:div :id "games-menu" :class "games-menu"
              (:div :class "games-grid"
               (:div :class "game-card" :data-game "lisp-invaders"
                :style "--accent: #22c55e"
                (cl-who:str "<svg class='game-icon' xmlns='http://www.w3.org/2000/svg' width='48' height='48' viewBox='0 0 48 48'><rect x='8' y='8' width='8' height='8' fill='#22c55e'/><rect x='32' y='8' width='8' height='8' fill='#22c55e'/><rect x='16' y='16' width='16' height='8' fill='#22c55e'/><rect x='8' y='24' width='32' height='8' fill='#22c55e'/><rect x='12' y='32' width='4' height='8' fill='#22c55e'/><rect x='32' y='32' width='4' height='8' fill='#22c55e'/><rect x='20' y='24' width='8' height='4' fill='#0a0a0a'/></svg>")
                (:h3 "Lisp Invaders")
                (:p (cl-who:str (tr :game-invaders-desc))))
               (:div :class "game-card" :data-game "lambda-runner"
                :style "--accent: #f59e0b"
                (cl-who:str "<svg class='game-icon' xmlns='http://www.w3.org/2000/svg' width='48' height='48' viewBox='0 0 48 48'><text x='50%' y='55%' text-anchor='middle' dominant-baseline='middle' font-size='32' font-family='monospace' font-weight='bold' fill='#f59e0b'>\xce\xbb</text></svg>")
                (:h3 "Lambda Runner")
                (:p (cl-who:str (tr :game-lambda-desc))))
               (:div :class "game-card" :data-game "paren-matcher"
                :style "--accent: #3b82f6"
                (cl-who:str "<svg class='game-icon' xmlns='http://www.w3.org/2000/svg' width='48' height='48' viewBox='0 0 48 48'><text x='25%' y='55%' text-anchor='middle' dominant-baseline='middle' font-size='28' font-family='monospace' font-weight='bold' fill='#3b82f6'>(</text><text x='75%' y='55%' text-anchor='middle' dominant-baseline='middle' font-size='28' font-family='monospace' font-weight='bold' fill='#3b82f6'>)</text></svg>")
                (:h3 "Paren Matcher")
                 (:p (cl-who:str (tr :game-paren-desc))))
               (:div :class "game-card" :data-game "s-dungeon"
                :style "--accent: #a855f7"
                (cl-who:str "<svg class='game-icon' xmlns='http://www.w3.org/2000/svg' width='48' height='48' viewBox='0 0 48 48'><rect x='8' y='8' width='32' height='32' rx='2' fill='none' stroke='#a855f7' stroke-width='2'/><rect x='12' y='12' width='8' height='8' fill='#a855f7' opacity='0.8'/><rect x='28' y='12' width='8' height='8' fill='#a855f7' opacity='0.8'/><rect x='12' y='28' width='8' height='8' fill='#a855f7' opacity='0.8'/><rect x='28' y='28' width='8' height='8' fill='#a855f7' opacity='0.8'/><rect x='20' y='20' width='8' height='8' fill='#a855f7'/><line x1='20' y1='16' x2='28' y2='16' stroke='#a855f7' stroke-width='1'/><line x1='20' y1='32' x2='28' y2='32' stroke='#a855f7' stroke-width='1'/><line x1='16' y1='20' x2='16' y2='28' stroke='#a855f7' stroke-width='1'/><line x1='32' y1='20' x2='32' y2='28' stroke='#a855f7' stroke-width='1'/></svg>")
                (:h3 "S-Expression Dungeon")
                (:p (cl-who:str (tr :game-dungeon-desc))))))
              (:div :id "game-play" :class "game-play" :style "display:none"
              (:button :class "game-back-btn" (cl-who:str (tr :game-back)))
              (:div :class "game-body"
               (:div :id "game-loading" :class "game-loading"
                (:div :class "game-loading-text" (cl-who:str (tr :game-loading)))
                (:div :class "game-loading-bar"
                 (:div :id "game-loading-fill" :class "game-loading-fill")))
               (:canvas :id "game-canvas" :width "640" :height "480"))
              (:div :class "game-footer"
                (:span :class "game-score-label" (cl-who:str (tr :game-score)))
                (:span :id "game-score" "0")
                 (:span :id "game-hint" :class "game-hint" "")))))
         ;; jscl.js (рантайм JSCL) + клиентский словарь i18n + site bundle
         (:script :defer t :src "/i18n.js")
         (:script :defer t :src (jscl-url))
         (:script :defer t :src (jscl-bundle-url "site")))))))
