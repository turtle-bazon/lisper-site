(defsystem :lisper
  :name "lisper"
  :license "GPL-3.0"
  :version "1.0.0"
  :description "lisper - site about Common Lisp"
  :depends-on (#:clack
               #:clack-handler-wookie
               #:cl-who
               #:cl-css
               #:cl-base64
               #:postmodern
               #:ironclad
                #:split-sequence
                #:flexi-streams
                #:uiop
                #:cl-maxminddb)
  :serial t
  :components ((:module "src"
                :components
                ((:file "package")
                 (:file "config")
                 (:file "i18n")
                 (:file "i18n-ru")
                 (:file "i18n-en")
                 (:file "i18n-tr")
                 (:file "i18n-uk")
                 (:file "resources")
                  (:file "game-sources")
                   (:file "tool-sources")
                   (:file "jscl-bundles")
                   (:file "migrations")
(:file "db")
                  (:file "auth")
                  (:file "forum")
                  (:file "analytics")
                 (:file "css")
                 (:file "js")
                 (:file "pages")
                 (:file "forum-pages")
                 (:file "routes")
                 (:file "main")))))
