(in-package :lisper)

;;; Автоматически сгенерировано build-resources.lisp
;;; Источники: jscl-tools/*.lisp

(defparameter *tool-sources* '
  (
    ("repl" "cl" ";;; jscl-tools/repl.lisp — REPL на чистом CL через JSCL
;;; Вся логика И DOM — на CL, прямые FFI-вызовы.

(defpackage :repl
  (:use :cl)
  (:import-from :jscl/ffi)
  (:export #:repl-start
           #:repl-enter
           #:repl-create-input-line
           #:dom-focus-last-input
           #:repl-arrow-up
           #:repl-arrow-down
           #:repl-get-prompt-text
           #:repl-make-dots
           #:repl-balanced-p
           #:dom-get-input-values
           #:dom-append-line
           #:dom-append-html
           #:dom-remove-input-lines))

(in-package :repl)

;;; ============================================================
;;; DOM helpers
;;; ============================================================

(defun dom-get-console ()
  ((jscl::oget #j:document \"getElementById\") #j\"repl-console\"))

(defun dom-append-line (text &optional (cls \"\"))
  (let ((c (dom-get-console)))
    (when c
      (let ((div ((jscl::oget #j:document \"createElement\") #j\"div\")))
        (setf (jscl::oget div \"className\")
              (if (string= cls \"\")
                  #j\"repl-line\"
                  (jscl/ffi:jsstring
                   (concatenate 'string \"repl-line \" cls))))
        (setf (jscl::oget div \"textContent\")
              (jscl/ffi:jsstring text))
        ((jscl::oget c \"appendChild\") div)
        (setf (jscl::oget c \"scrollTop\") (jscl::oget c \"scrollHeight\"))))))

(defun dom-append-html (html &optional (cls \"\"))
  (let ((c (dom-get-console)))
    (when c
      (let ((div ((jscl::oget #j:document \"createElement\") #j\"div\")))
        (setf (jscl::oget div \"className\")
              (if (string= cls \"\")
                  #j\"repl-line\"
                  (jscl/ffi:jsstring
                   (concatenate 'string \"repl-line \" cls))))
        (if (jscl::oget #j:window \"DOMPurify\")
            (setf (jscl::oget div \"innerHTML\")
                  ((jscl::oget #j:DOMPurify \"sanitize\")
                   (jscl/ffi:jsstring html)))
            (setf (jscl::oget div \"textContent\")
                  (jscl/ffi:jsstring html)))
        ((jscl::oget c \"appendChild\") div)
        (setf (jscl::oget c \"scrollTop\") (jscl::oget c \"scrollHeight\"))))))

(defun dom-remove-input-lines ()
  (let ((c (dom-get-console)))
    (when c
      (let ((lines ((jscl::oget c \"querySelectorAll\") #j\".repl-input-line\")))
        (loop for i from 0 below (jscl::oget lines \"length\")
              do ((jscl::oget (jscl::oget lines i) \"remove\"))))))
  nil)

(defun dom-focus-last-input ()
  (let* ((c (dom-get-console))
         (inp (when c ((jscl::oget c \"querySelector\") #j\".repl-input-line:last-child .repl-input\"))))
    (when inp ((jscl::oget inp \"focus\")))))

(defun dom-close-repl ()
  (let ((overlay ((jscl::oget #j:document \"getElementById\") #j\"repl-overlay\")))
    (when overlay ((jscl::oget overlay \"classList\") \"remove\" #j\"active\"))))

;;; ============================================================
;;; Read input from DOM
;;; ============================================================

(defun dom-get-input-values ()
  \"Return list of CL strings from all .repl-input elements.\"
  (let ((lines ((jscl::oget #j:document \"querySelectorAll\")
                #j\".repl-input-line .repl-input\"))
        (result nil))
    (loop for i from 0 below (jscl::oget lines \"length\")
          do (push ((jscl::oget #j:jscl \"internals\" \"make_lisp_string\")
                     (jscl::oget (jscl::oget lines i) \"value\"))
                   result))
    (nreverse result)))

;;; ============================================================
;;; Balanced check
;;; ============================================================

(defun repl-balanced-p (input)
  (let ((depth 0) (in-string nil) (escaped nil) (in-comment nil))
    (loop for ch across input
          do (cond
               (in-comment
                (when (char= ch #\\Newline)
                  (setf in-comment nil)))
               (escaped
                (setf escaped nil))
               ((char= ch #\\\\)
                (setf escaped t))
               ((char= ch #\\;)
                (setf in-comment t))
               ((char= ch #\\\")
                (setf in-string (not in-string)))
               (in-string nil)
               (t
                (when (member ch '(#\\( #\\[) :test #'char=)
                  (incf depth))
                (when (member ch '(#\\) #\\]) :test #'char=)
                  (decf depth))
                (when (< depth 0) (return-from repl-balanced-p nil)))))
    (zerop depth)))

;;; ============================================================
;;; Prompt & dots
;;; ============================================================

(defun repl-get-prompt-text ()
  (let ((nicks (package-nicknames *package*)))
    (format nil \"~A> \" (if nicks (first nicks) (package-name *package*)))))

(defun repl-make-dots (prompt-text)
  (let ((n (max 0 (1- (length prompt-text)))))
    (concatenate 'string
                 (make-string n :initial-element #\\.)
                 \" \")))

;;; ============================================================
;;; Input line creation
;;; ============================================================

(defun repl-create-input-line (&optional is-continuation dots)
  (let* ((prompt (if is-continuation
                     (or dots (repl-make-dots (repl-get-prompt-text)))
                     (repl-get-prompt-text)))
         (c (dom-get-console)))
    (when c
      (let ((line ((jscl::oget #j:document \"createElement\") #j\"div\")))
        (setf (jscl::oget line \"className\") #j\"repl-line repl-input-line\")

        (let ((prompt-span ((jscl::oget #j:document \"createElement\") #j\"span\")))
          (setf (jscl::oget prompt-span \"className\") #j\"repl-prompt-label\")
          (setf (jscl::oget prompt-span \"textContent\") (jscl/ffi:jsstring prompt))
          ((jscl::oget line \"appendChild\") prompt-span))

        (let ((inp ((jscl::oget #j:document \"createElement\") #j\"input\")))
          (setf (jscl::oget inp \"type\") #j\"text\")
          (setf (jscl::oget inp \"className\") #j\"repl-input\")
          (setf (jscl::oget inp \"autocomplete\") #j\"off\")
          (setf (jscl::oget inp \"spellcheck\") #j\"false\")
          ((jscl::oget line \"appendChild\") inp)
          ((jscl::oget c \"appendChild\") line)
          (setf (jscl::oget c \"scrollTop\") (jscl::oget c \"scrollHeight\"))
          ((jscl::oget inp \"focus\")))))))

;;; ============================================================
;;; History
;;; ============================================================

(defvar *repl-history* nil)
(defvar *repl-history-idx* 0)

(defun repl-history-push (entry)
  (setf *repl-history* (append *repl-history* (list entry)))
  (setf *repl-history-idx* (length *repl-history*)))

(defun repl-history-length ()
  (length *repl-history*))

(defun repl-history-current ()
  (let ((idx *repl-history-idx*))
    (when (< idx (repl-history-length))
      (nth idx *repl-history*))))

;;; ============================================================
;;; Arrow key navigation
;;; ============================================================

(defun repl-restore-history ()
  (if (>= *repl-history-idx* (repl-history-length))
      (progn
        (dom-remove-input-lines)
        (repl-create-input-line))
      (let ((entry (repl-history-current)))
        (dom-remove-input-lines)
        (let ((entry-lines (jscl::oget entry \"lines\"))
              (entry-dots (jscl::oget entry \"dots\")))
          (loop for i from 0 below (jscl::oget entry-lines \"length\")
                do (repl-create-input-line (> i 0) (when (> i 0) entry-dots))
                   (let ((inp ((jscl::oget #j:document \"querySelector\")
                               #j\".repl-input-line:last-child .repl-input\")))
                     (when inp
                       (setf (jscl::oget inp \"value\")
                             (jscl::oget entry-lines i))))))
        (dom-focus-last-input))))

(defun repl-arrow-up ()
  (let ((lines ((jscl::oget #j:document \"querySelectorAll\") #j\".repl-input-line .repl-input\"))
        (active (jscl::oget #j:document \"activeElement\")))
    (when (and active (> (jscl::oget lines \"length\") 0))
      (let ((idx -1))
        (loop for i from 0 below (jscl::oget lines \"length\")
              do (when (eq (jscl::oget lines i) active) (setf idx i)))
        (when (>= idx 0)
          (let ((is-first (= idx 0))
                (is-last (= idx (1- (jscl::oget lines \"length\"))))
                (at-start (= (jscl::oget active \"selectionStart\") 0))
                (at-end (= (jscl::oget active \"selectionStart\")
                           (jscl::oget active \"value\" \"length\"))))
            (if (or (and is-first at-start) (and is-last at-end))
                (when (> (repl-history-length) 0)
                  (when (> *repl-history-idx* 0)
                    (decf *repl-history-idx*)
                    (repl-restore-history)))
                (when (> idx 0)
                  (let ((prev (jscl::oget lines (1- idx))))
                    ((jscl::oget prev \"focus\"))
                    (let ((pos (min (jscl::oget active \"selectionStart\")
                                    (jscl::oget prev \"value\" \"length\"))))
                      (setf (jscl::oget prev \"selectionStart\") pos
                            (jscl::oget prev \"selectionEnd\") pos)))))))))))

(defun repl-arrow-down ()
  (let ((lines ((jscl::oget #j:document \"querySelectorAll\") #j\".repl-input-line .repl-input\"))
        (active (jscl::oget #j:document \"activeElement\")))
    (when (and active (> (jscl::oget lines \"length\") 0))
      (let ((idx -1)
            (len (jscl::oget lines \"length\")))
        (loop for i from 0 below len
              do (when (eq (jscl::oget lines i) active) (setf idx i)))
        (when (>= idx 0)
          (let ((is-first (= idx 0))
                (is-last (= idx (1- len)))
                (at-start (= (jscl::oget active \"selectionStart\") 0))
                (at-end (= (jscl::oget active \"selectionStart\")
                           (jscl::oget active \"value\" \"length\"))))
            (if (or (and is-first at-start) (and is-last at-end))
                (when (> (repl-history-length) 0)
                  (if (< *repl-history-idx* (1- (repl-history-length)))
                      (progn
                        (incf *repl-history-idx*)
                        (repl-restore-history))
                      (progn
                        (setf *repl-history-idx* (repl-history-length))
                        (dom-remove-input-lines)
                        (repl-create-input-line))))
                (when (< idx (1- len))
                  (let ((next (jscl::oget lines (1+ idx))))
                    ((jscl::oget next \"focus\"))
                    (let ((pos (min (jscl::oget active \"selectionStart\")
                                    (jscl::oget next \"value\" \"length\"))))
                      (setf (jscl::oget next \"selectionStart\") pos
                            (jscl::oget next \"selectionEnd\") pos)))))))))))

;;; ============================================================
;;; Enter key handling — читает из DOM, управляет историей
;;; ============================================================

(defun repl-enter (shift-p)
  \"Called from JS on Enter. Reads DOM, checks balance, submits or continues.\"
  (let* ((values (dom-get-input-values))
         (input (format nil \"~{~A~^ ~}\" values))
         (prompt (repl-get-prompt-text))
         (dots (repl-make-dots prompt)))
    (when (string= input \"\")
      (repl-create-input-line)
      (return-from repl-enter))
    (if (or shift-p (not (repl-balanced-p input)))
        ;; Not balanced or shift: add continuation line
        (progn
          ;; Mark all current inputs readonly
          (let ((lines ((jscl::oget #j:document \"querySelectorAll\")
                        #j\".repl-input-line .repl-input\")))
            (loop for i from 0 below (jscl::oget lines \"length\")
                  do (setf (jscl::oget (jscl::oget lines i) \"readOnly\") #j\"true\")))
          (repl-create-input-line t dots))
        ;; Balanced: submit
        (progn
          ;; Remove input lines from DOM
          (dom-remove-input-lines)
          ;; Show history lines
          (loop for i from 0 below (length values)
                do (dom-append-line
                    (concatenate 'string
                                 (if (= i 0) prompt dots)
                                 (nth i values))
                    \"repl-history\"))
          ;; Push to history
          (let ((entry ((jscl::oget #j:Object \"create\") #j:null)))
            (setf (jscl::oget entry \"lines\")
                  (let ((arr ((jscl::oget #j:Array))))
                    (loop for i from 0 below (length values)
                          do ((jscl::oget arr \"push\")
                              (jscl/ffi:jsstring (nth i values))))
                    arr))
            (setf (jscl::oget entry \"prompt\") (jscl/ffi:jsstring prompt))
            (setf (jscl::oget entry \"dots\") (jscl/ffi:jsstring dots))
            (repl-history-push entry))
          ;; Evaluate
          (handler-case
              (let* ((form (read-from-string input))
                     (result (eval form)))
                (let ((printed (princ-to-string result)))
                  (when (and printed (> (length printed) 0))
                    (dom-append-line (concatenate 'string \"=> \" printed) \"repl-result\"))))
            (error (e)
              (dom-append-line (format nil \"Error: ~A\" e) \"repl-error\")))
          (repl-create-input-line)))))

;;; ============================================================
;;; REPL start
;;; ============================================================

(defun repl-start ()
  (setf *package* (find-package \"COMMON-LISP-USER\"))
  (dom-remove-input-lines)
  (dom-append-html
   \"<span class=\\\"repl-credit\\\">Powered by <a href=\\\"https://github.com/jscl-project/jscl\\\" target=\\\"_blank\\\">JSCL</a></span>\"
   \"repl-header-line\")
  (repl-create-input-line))

(shadowing-import '(repl-start repl-enter repl-create-input-line
                    dom-focus-last-input repl-arrow-up repl-arrow-down)
                  (find-package \"COMMON-LISP-USER\"))
")
    ))

(defun get-tool-source (name)
  "Возвращает (lang . source) утилиты по имени."
  (let ((g (assoc name *tool-sources* :test #'string=)))
    (when g (cons (second g) (third g)))))
