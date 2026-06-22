(defsystem :lisper
  :name "lisper"
  :license "GPL-3.0"
  :version "1.0.0"
  :description "lisper.ru - site about Common Lisp"
  :depends-on (#:clack
               #:clack-handler-wookie
               #:cl-who
               #:cl-css
               #:uiop)
  :serial t
  :components ((:module "src"
                :components
                ((:file "package")
                 (:file "config")
                 (:file "css")
                 (:file "js")
                 (:file "pages")
                 (:file "routes")
                 (:file "main")))))
