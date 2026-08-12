;;; jscl-tools/site.lisp — клиентский код сайта на чистом CL (через JSCL).
;;; Компилируется node-ом в бандл /jscl-bundle/site.
;;; Прелюдию (defpackage :site + *site-bundle-urls*) генерирует build-resources.lisp
;;; и компилирует её вместе с этим файлом в один бандл.
;;;
;;; Отвечает за: REPL-модалку, Lisp-игры, markdown-рендер + markdown-редактор.
;;; REPL и игры — отдельные бандлы, вызываются кросс-пакетно через
;;; jscl.packages[PKG].symbols[SYM].fvalue.

(in-package :site)

;;; ============================================================
;;; FFI-хелперы
;;; ============================================================

(defun js-str (s) (jscl/ffi:jsstring s))
(defun cl-str (s) (jscl/ffi:clstring s))
(defun js-bool (b) (jscl/ffi:jsbool b))
(defun cl-bool (b) (jscl/ffi:clbool b))

(defun el-by-id (id)
  "Возвращает элемент или CL NIL (JS null → NIL, чтобы (when el ...) работал)."
  (let ((el ((jscl::oget #j:document "getElementById") (js-str id))))
    (if (eq el #j:null) nil el)))

(defun qsa (sel)
  "querySelectorAll — возвращает JS NodeList (или пустой)."
  ((jscl::oget #j:document "querySelectorAll") (js-str sel)))

(defun qsa-len (nodes) (jscl::oget nodes "length"))
(defun qsa-item (nodes i) (jscl::oget nodes i))

(defun listen (el type handler)
  ((jscl::oget el "addEventListener") (js-str type) handler))

(defun set-text (el s)
  (setf (jscl::oget el "textContent") (js-str s)))

(defun get-text (el)
  (cl-str (jscl::oget el "textContent")))

(defun set-html (el s)
  (setf (jscl::oget el "innerHTML") (js-str s)))

(defun get-value (el)
  (cl-str (jscl::oget el "value")))

(defun set-value (el s)
  (setf (jscl::oget el "value") (js-str s)))

(defun set-display (el value)
  (setf (jscl::oget (jscl::oget el "style") "display") (js-str value)))

(defun set-style (el prop value)
  (setf (jscl::oget (jscl::oget el "style") (js-str prop)) (js-str value)))

(defun set-selection (el start end)
  (setf (jscl::oget el "selectionStart") start
        (jscl::oget el "selectionEnd") end))

(defun has-class-p (el cls)
  (cl-bool ((jscl::oget (jscl::oget el "classList") "contains") (js-str cls))))

(defun add-class (el cls)
  ((jscl::oget (jscl::oget el "classList") "add") (js-str cls)))

(defun remove-class (el cls)
  ((jscl::oget (jscl::oget el "classList") "remove") (js-str cls)))

(defun site-log (&rest parts)
  ((jscl::oget #j:console "log") (js-str (apply #'concatenate 'string parts))))

(defun site-log-error (&rest parts)
  ((jscl::oget #j:console "error") (js-str (apply #'concatenate 'string parts))))

;;; ============================================================
;;; Кросс-пакетные вызовы (REPL и игры — отдельные бандлы)
;;; ============================================================

(defun pkg-sym (pkgname symname)
  "Символ SYMNAME в пакете PKGNAME или CL NIL."
  (let ((pkg (jscl::oget #j:jscl:packages (js-str pkgname))))
    (when (not (eq pkg #j:undefined))
      (let ((sym (jscl::oget (jscl::oget pkg "symbols") (js-str symname))))
        (when (not (eq sym #j:undefined)) sym)))))

(defun pkg-fn (pkgname symname)
  "fvalue (JS-функция) символа или CL NIL."
  (let ((sym (pkg-sym pkgname symname)))
    (when sym (jscl::oget sym "fvalue"))))

(defun call-pkg-fn (pkgname symname &rest args)
  "Вызвать функцию из другого пакета, если она существует."
  (let ((fn (pkg-fn pkgname symname)))
    (when fn (apply fn args))))

(defun bundle-url (name)
  "URL версионированного бандла или CL NIL (из прелюдии)."
  (cdr (assoc name *site-bundle-urls* :test #'string=)))

;;; ============================================================
;;; loadScript
;;; ============================================================

(defun load-script (url &optional (onload nil))
  "Добавляет <script src=url> в head; по загрузке вызывает ONLOAD."
  (let ((s ((jscl::oget #j:document "createElement") #j"script")))
    (setf (jscl::oget s "src") (js-str url))
    (when onload
      (setf (jscl::oget s "onload")
            (lambda (e) (declare (ignore e)) (funcall onload))))
    ((jscl::oget (jscl::oget #j:document "head") "appendChild") s)
    s))

;;; ============================================================
;;; REPL
;;; ============================================================

(defvar *repl-loaded* nil)
(defvar *repl-loading* nil)

(defun repl-append-error-line (c text)
  (let ((div ((jscl::oget #j:document "createElement") #j"div")))
    (setf (jscl::oget div "className") #j"repl-line repl-error")
    (set-text div text)
    ((jscl::oget c "appendChild") div)
    (setf (jscl::oget c "scrollTop") (jscl::oget c "scrollHeight"))))

(defun site-open-repl ()
  (let ((overlay (el-by-id "repl-overlay")))
    (when overlay (add-class overlay "active")))
  (let ((c (el-by-id "repl-console")))
    (when c
      (cond
        (*repl-loaded*
         (call-pkg-fn "REPL" "DOM-FOCUS-LAST-INPUT"))
        (*repl-loading* nil)
        (t
         (setf *repl-loading* t)
         (set-html c "")
         (let ((url (bundle-url "repl")))
           (if url
               (load-script
                url
                (lambda ()
                  (setf *repl-loading* nil)
                  (setf *repl-loaded* t)
                  (set-html c "")
                  (handler-case
                      (call-pkg-fn "REPL" "REPL-START")
                    (error (e)
                      (repl-append-error-line
                       c (format nil "Error starting REPL: ~A" e))
                      (call-pkg-fn "REPL" "REPL-CREATE-INPUT-LINE")))))
               (progn
                 (setf *repl-loading* nil)
                 (repl-append-error-line
                  c "Error: repl bundle not available (build without node?)")))))))))

(defun site-close-repl ()
  (let ((overlay (el-by-id "repl-overlay")))
    (when overlay (remove-class overlay "active"))))

;;; ============================================================
;;; Игры
;;; ============================================================

(defvar *game-anim-frame* nil)
(defvar *game-loop-fn* nil)
(defvar *game-loop-alive* nil)

(defun game-hint-for (name)
  (cdr (assoc name
              '(("lisp-invaders" . "← → — движение | пробел — стрелять | P — пауза | Enter — заново")
                ("lambda-runner" . "пробел — прыжок | P — пауза | Enter — заново")
                ("paren-matcher" . "← → A D — лови скобки | P — пауза | Enter — заново")
                ("s-dungeon" . "← → ↑ ↓ WASD — движение | . — ждать | Enter — заново"))
              :test #'string=)))

(defun site-games-show-menu ()
  (let ((menu (el-by-id "games-menu"))
        (play (el-by-id "game-play"))
        (title (el-by-id "games-modal-title")))
    (when menu (set-display menu ""))
    (when play (set-display play "none"))
    (when title
      (set-text title "Lisp Игры")
      (setf (jscl::oget title "href") (js-str "#")))))

(defun site-games-open ()
  (let ((overlay (el-by-id "games-overlay")))
    (when overlay (add-class overlay "active")))
  (site-games-show-menu))

(defun site-game-stop-loop ()
  (setf *game-loop-alive* nil)
  (when *game-anim-frame*
    ((jscl::oget #j:window "cancelAnimationFrame") *game-anim-frame*)
    (setf *game-anim-frame* nil))
  (setf *game-loop-fn* nil))

(defun game-tick (_ts)
  (declare (ignore _ts))
  (when *game-loop-alive*
    (when *game-loop-fn*
      (handler-case (funcall *game-loop-fn*)
        (error (e)
          (site-log-error "game-loop error: " (princ-to-string e)))))
    (setf *game-anim-frame*
          ((jscl::oget #j:window "requestAnimationFrame")
           (lambda (ts) (game-tick ts))))))

(defun site-game-start-compiled (name)
  (let ((pkg-name (string-upcase name)))
    (handler-case
        (call-pkg-fn pkg-name (format nil "START-~A" pkg-name))
      (error (e)
        (site-log-error "start-" name " failed: " (princ-to-string e))))
    (setf *game-loop-fn* (pkg-fn pkg-name "GAME-LOOP-RAW"))
    (setf *game-loop-alive* t)
    (setf *game-anim-frame*
          ((jscl::oget #j:window "requestAnimationFrame")
           (lambda (ts) (game-tick ts))))))

(defun site-game-show-error (text)
  (let ((play (el-by-id "game-play")))
    (when play
      (set-html play
                (format nil "<div style=\"color:#ef4444;padding:40px;text-align:center\"><h3>Ошибка загрузки игры</h3><p>~A</p></div>"
                        text)))))

(defun site-game-start (name)
  (site-game-stop-loop)
  (let ((menu (el-by-id "games-menu"))
        (play (el-by-id "game-play"))
        (title (el-by-id "games-modal-title"))
        (hint (el-by-id "game-hint"))
        (loading (el-by-id "game-loading"))
        (fill (el-by-id "game-loading-fill")))
    (when menu (set-display menu "none"))
    (when play (set-display play "flex"))
    (when title
      (set-text title name)
      (setf (jscl::oget title "href") (js-str (format nil "/game-source/~a" name))))
    (when hint (set-text hint (or (game-hint-for name) "")))
    (when loading (set-display loading ""))
    (when fill (set-style fill "width" "0%")))
  (let ((url (bundle-url name)))
    (if url
        (load-script
         url
         (lambda ()
           (let ((loading (el-by-id "game-loading")))
             (when loading (set-display loading "none")))
           (site-game-start-compiled name)))
        (progn
          (let ((loading (el-by-id "game-loading")))
            (when loading (set-display loading "none")))
          (site-game-show-error "Бандл и исходник недоступны")))))

(defun site-game-back ()
  (site-game-stop-loop)
  (site-games-show-menu))

(defun site-game-close ()
  (let ((overlay (el-by-id "games-overlay")))
    (when overlay (remove-class overlay "active")))
  (site-game-stop-loop)
  (site-games-show-menu))

;;; ============================================================
;;; Markdown (рендер .md-content + .md-editor)
;;; ============================================================

(defun marked-defined-p ()
  (not (eq (jscl::oget #j:window "marked") #j:undefined)))

(defun sanitize-html (html)
  "Прогнать HTML (CL-строка) через DOMPurify; без DOMPurify — вернуть как есть."
  (let ((purify (jscl::oget #j:window "DOMPurify")))
    (if (eq purify #j:undefined)
        html
        (cl-str ((jscl::oget purify "sanitize") (js-str html))))))

(defun highlight-pre-code (root)
  (when (not (eq (jscl::oget #j:window "hljs") #j:undefined))
    (let ((blocks ((jscl::oget root "querySelectorAll") #j"pre code")))
      (loop for i from 0 below (jscl::oget blocks "length")
            do ((jscl::oget #j:hljs "highlightElement") (jscl::oget blocks i))))))

(defun set-markdown-options ()
  (when (marked-defined-p)
    (let ((opts (#j:Reflect:construct #j:Object (#j:Array))))
      (setf (jscl::oget opts "breaks") (js-bool t))
      (setf (jscl::oget opts "gfm") (js-bool t))
      ((jscl::oget #j:marked "setOptions") opts))))

(defun render-markdown-to (el)
  "el.textContent → marked.parse → DOMPurify → hljs.highlightElement."
  (when (marked-defined-p)
    (let ((raw ((jscl::oget #j:marked "parse") (js-str (get-text el)))))
      (set-html el (sanitize-html (cl-str raw)))
      (highlight-pre-code el))))

;;; --- Markdown-редактор ---

(defun md-insert-around (ta before after)
  (let* ((start (jscl::oget ta "selectionStart"))
         (end (jscl::oget ta "selectionEnd"))
         (value (get-value ta))
         (sel (subseq value start end)))
    (set-value ta (concatenate 'string
                               (subseq value 0 start) before sel after
                               (subseq value end)))
    (set-selection ta (+ start (length before)) (+ start (length before) (length sel)))
    ((jscl::oget ta "focus"))))

(defun md-line-start (value start)
  "Начало строки, содержащей позицию START."
  (let ((nl (position #\Newline value :from-end t :end start)))
    (if nl (1+ nl) 0)))

(defun md-insert-line (ta prefix)
  (let* ((start (jscl::oget ta "selectionStart"))
         (value (get-value ta))
         (ls (md-line-start value start)))
    (set-value ta (concatenate 'string (subseq value 0 ls) prefix (subseq value ls)))
    (set-selection ta (+ start (length prefix)) (+ start (length prefix)))
    ((jscl::oget ta "focus"))))

(defun md-tab (ta)
  (let* ((start (jscl::oget ta "selectionStart"))
         (end (jscl::oget ta "selectionEnd"))
         (value (get-value ta)))
    (set-value ta (concatenate 'string (subseq value 0 start) "  " (subseq value end)))
    (set-selection ta (+ start 2) (+ start 2))))

(defun md-toggle-preview (ta preview btn)
  (if (has-class-p btn "active")
      (progn
        (set-display preview "none")
        (set-display ta "block")
        (remove-class btn "active")
        ((jscl::oget ta "focus")))
      (progn
        (when (marked-defined-p)
          (let ((src (get-value ta)))
            (when (string= src "") (setf src "_Пусто_"))
            (let ((raw ((jscl::oget #j:marked "parse") (js-str src))))
              (set-html preview (sanitize-html (cl-str raw)))
              (highlight-pre-code preview))))
        (set-display preview "block")
        (set-display ta "none")
        (add-class btn "active"))))

(defun site-init-editor (editor)
  (let ((ta ((jscl::oget editor "querySelector") #j".md-textarea"))
        (preview ((jscl::oget editor "querySelector") #j".md-preview")))
    (when (and (not (eq ta #j:null)) (not (eq preview #j:null)))
      (let ((btns ((jscl::oget editor "querySelectorAll") #j".md-btn")))
        (loop for i from 0 below (jscl::oget btns "length")
              do (let ((btn (jscl::oget btns i)))
                   (listen btn "click"
                           (lambda (e)
                             ((jscl::oget e "preventDefault"))
                             (let ((action (cl-str ((jscl::oget btn "getAttribute") #j"data-action"))))
                               (cond
                                 ((string= action "bold") (md-insert-around ta "**" "**"))
                                 ((string= action "italic") (md-insert-around ta "*" "*"))
                                 ((string= action "strike") (md-insert-around ta "~~" "~~"))
                                 ((string= action "h1") (md-insert-line ta "# "))
                                 ((string= action "h2") (md-insert-line ta "## "))
                                 ((string= action "h3") (md-insert-line ta "### "))
                                 ((string= action "ul") (md-insert-line ta "- "))
                                 ((string= action "ol") (md-insert-line ta "1. "))
                                 ((string= action "quote") (md-insert-line ta "> "))
                                 ((string= action "code")
                                  (md-insert-around ta (format nil "~%```~%") (format nil "~%```~%")))
                                 ((string= action "link") (md-insert-around ta "[" "](url)"))
                                 ((string= action "image") (md-insert-around ta "![alt](" ")"))
                                 ((string= action "preview") (md-toggle-preview ta preview btn)))))))))
      (listen ta "keydown"
              (lambda (e)
                (let ((key (cl-str (jscl::oget e "key"))))
                  (when (string= key "Tab")
                    ((jscl::oget e "preventDefault"))
                    (md-tab ta))))))))

(defun site-init-markdown ()
  (set-markdown-options)
  (let ((contents (qsa ".md-content")))
    (loop for i from 0 below (qsa-len contents)
          do (render-markdown-to (qsa-item contents i))))
  (let ((editors (qsa ".md-editor")))
    (loop for i from 0 below (qsa-len editors)
          do (site-init-editor (qsa-item editors i)))))

;;; ============================================================
;;; Wiring обработчиков
;;; ============================================================

(defun site-init-repl ()
  (let ((btn (el-by-id "try-repl-btn")))
    (when btn
      (listen btn "click"
              (lambda (e)
                ((jscl::oget e "preventDefault"))
                (site-open-repl)))))
  (let ((closes (qsa ".repl-close")))
    (loop for i from 0 below (qsa-len closes)
          do (let ((btn (qsa-item closes i)))
               (listen btn "click"
                       (lambda (e)
                         ((jscl::oget e "preventDefault"))
                         ((jscl::oget e "stopPropagation"))
                         (site-close-repl)))))))

(defun site-init-games ()
  (let ((nav (el-by-id "games-nav-btn")))
    (when nav
      (listen nav "click"
              (lambda (e)
                ((jscl::oget e "preventDefault"))
                (site-games-open)))))
  (let ((cards (qsa ".game-card")))
    (loop for i from 0 below (qsa-len cards)
          do (let ((card (qsa-item cards i)))
               (listen card "click"
                       (lambda (e)
                         ((jscl::oget e "preventDefault"))
                         (let ((game (cl-str ((jscl::oget card "getAttribute") #j"data-game"))))
                           (when game (site-game-start game))))))))
  (let ((backs (qsa ".game-back-btn")))
    (loop for i from 0 below (qsa-len backs)
          do (let ((btn (qsa-item backs i)))
               (listen btn "click"
                       (lambda (e)
                         ((jscl::oget e "preventDefault"))
                         (site-game-back))))))
  (let ((closes (qsa ".game-close")))
    (loop for i from 0 below (qsa-len closes)
          do (let ((btn (qsa-item closes i)))
               (listen btn "click"
                       (lambda (e)
                         ((jscl::oget e "preventDefault"))
                         ((jscl::oget e "stopPropagation"))
                         (site-game-close)))))))

(defun site-handle-keydown (e)
  (let ((key (cl-str (jscl::oget e "key"))))
    (cond
      ((string= key "Escape")
       (let ((repl (el-by-id "repl-overlay"))
             (games (el-by-id "games-overlay")))
         (when (and repl (has-class-p repl "active")) (site-close-repl))
         (when (and games (has-class-p games "active")) (site-game-close))))
      ((string= key "Enter")
       (let ((inp ((jscl::oget #j:document "querySelector")
                   #j".repl-input-line:last-child .repl-input")))
         (when (and (not (eq inp #j:null))
                    (eq (jscl::oget #j:document "activeElement") inp))
           (unless (cl-bool (jscl::oget inp "disabled"))
             ((jscl::oget e "preventDefault"))
             (call-pkg-fn "REPL" "REPL-ENTER"
                          (cl-bool (jscl::oget e "shiftKey")))))))
      ((or (string= key "ArrowUp") (string= key "ArrowDown"))
       (let ((active (jscl::oget #j:document "activeElement")))
         (when (and (not (eq active #j:null)) (has-class-p active "repl-input"))
           ((jscl::oget e "preventDefault"))
           (call-pkg-fn "REPL"
                        (if (string= key "ArrowUp") "REPL-ARROW-UP" "REPL-ARROW-DOWN"))))))))

(defun site-init (&optional e)
  (declare (ignore e))
  (site-log "site bundle: init")
  (site-init-repl)
  (site-init-games)
  (site-init-markdown)
  (listen #j:document "keydown" #'site-handle-keydown))

(defun site-boot ()
  (let ((state (cl-str (jscl::oget #j:document "readyState"))))
    (if (or (string= state "interactive") (string= state "complete"))
        (site-init)
        (listen #j:document "DOMContentLoaded" #'site-init))))

(site-boot)
