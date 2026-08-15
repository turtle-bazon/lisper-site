(jscl:compile-application
 (list "jscl-tools/markdown.lisp")
 "@BUNDLE@"
 :place ""
 :jscl-name "jscl")

(format t "~&MD-COMPILE-OK~%")