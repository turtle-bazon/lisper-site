(defsystem :lisper
  :name "lisper"
  :license "GPL-3.0"
  :version "1.0.0"
  :description "lisper.ru - site about Common Lisp"
  :depends-on (#:clack
               #:clack-handler-wookie
               #:cl-who
               #:cl-css
               #:cl-base64
               #:postmodern
               #:ironclad
               #:split-sequence
               #:flexi-streams
               #:uiop)
  :serial t
  :components ((:module "src"
                :components
                ((:file "package")
                 (:file "config")
                 (:file "resources")
                  (:file "game-sources")
                   (:file "tool-sources")
                   (:file "migrations")
                 (:file "db")
                 (:file "auth")
                 (:file "forum")
                 (:file "css")
                 (:file "js")
                 (:file "pages")
                 (:file "forum-pages")
                 (:file "routes")
                 (:file "main")))))
