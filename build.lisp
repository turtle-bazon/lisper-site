(defparameter *project-name* "lisper")

(defun build-suffix ()
  "prod/Container.stage1 passes BUILD_SUFFIX=-stage1 so the extracted binary
   is build/lisper-stage1 and does not clobber the host's build/lisper."
  (or (uiop:getenv "BUILD_SUFFIX") ""))

(defun build-arguments ()
  `("" "--load" "~/.sbclrc"
    "--eval" "(push :binary *features*)"
    "--asdf-path" "."
    "--load-system" ,*project-name*
    "--entry" ,(format nil "~a:main" *project-name*)
    "--output" ,(format nil "build/~a~a" *project-name* (build-suffix))))

(ql:quickload *project-name*)
(ql:quickload "buildapp")
(ensure-directories-exist "build")
(buildapp::main (build-arguments))
(quit)
