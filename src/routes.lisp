(in-package :lisper)

(defun make-app ()
  (lambda (env)
    (let ((path (getf env :path-info)))
      (cond
        ((string= path "/")
         `(200 (:content-type "text/html; charset=utf-8")
               (,(page-index))))
        ((string= path "/css")
         `(200 (:content-type "text/css; charset=utf-8")
               (,(generate-css))))
        ((string= path "/js")
         `(200 (:content-type "application/javascript; charset=utf-8")
               (,(generate-js))))
        (t
         '(404 (:content-type "text/html; charset=utf-8")
           ("<h1>404</h1>")))))))
