(defparameter *project-name* "lisper")

(defun build-arguments ()
  `("" "--load" "~/.sbclrc"
    "--eval" "(push :binary *features*)"
    "--asdf-path" "."
    "--load-system" ,*project-name*
    "--entry" ,(format nil "~a:main" *project-name*)
    "--output" ,(format nil "build/~a" *project-name*)))

(ql:quickload *project-name*)
(ql:quickload "buildapp")
(ensure-directories-exist "build")
(buildapp::main (build-arguments))
(quit)
