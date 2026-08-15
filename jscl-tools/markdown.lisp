;;; jscl-tools/markdown.lisp — CommonMark-совместимый markdown-рендер на чистом CL.
;;; Компилируется node-ом вместе с site.lisp в бандл /jscl-bundle/site.
;;;
;;; Заменяет внешний marked + DOMPurify:
;;;   * парсинг блоков и инлайнов по алгоритмам CommonMark;
;;;   * HTML-рендер с обязательным экранированием текста/атрибутов и
;;;     ограничением URL-схем (sanitizer встроен — raw HTML не пропускается,
;;;     html-блоки/теги рендерятся как текст);
;;;   * только стандартный CL (JSCL: без регулярок).

(defpackage :markdown
  (:use :cl)
  (:export :render-to-html))

(in-package :markdown)

;;; ============================================================
;;; Строковые утилиты
;;; ============================================================

(defun is-space (c) (or (char= c #\Space) (char= c #\Tab)))

(defun is-blank-str (s)
  (let ((len (length s)))
    (loop for i from 0 below len
          when (not (is-space (char s i))) do (return-from is-blank-str nil))
    t))

(defun skip-spaces (s start)
  (loop for i from start below (length s)
        while (is-space (char s i))
        finally (return i)))

(defun prefix-p (s prefix start)
  (let ((plen (length prefix)))
    (and (<= (+ start plen) (length s))
         (loop for i from 0 below plen
               always (char= (char s (+ start i)) (char prefix i))))))

(defparameter +ascii-punct+ "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~")

(defun ascii-punct-p (c)
  (find c +ascii-punct+))

(defun split-lines (text)
  "Разбить на строки. Нормализуем \r\n → \n, \r → \n (CommonMark)."
  (let* ((s (substitute #\Newline #\Return text))
         (out '())
         (start 0)
         (len (length s)))
    (loop for i from 0 below len
          when (char= (char s i) #\Newline)
            do (push (subseq s start i) out)
               (setf start (1+ i)))
    (push (subseq s start) out)
    (nreverse out)))

(defparameter *nl* (format nil "~%")
  "Новая строка. JSCL-читатель превращает \"\\n\" в литеральную букву n,
   поэтому перенос строится через format \"~%\".")

(defun join-lines (lines)
  (format nil "~{~A~^~%~}" lines))

(defun trim-str (s)
  (string-trim '(#\Space #\Tab) s))

(defun leading-spaces (line)
  (loop for i from 0 below (length line)
        while (is-space (char line i))
        count i))

(defun trailing-spaces-end (text i)
  (loop for j from i below (length text)
        while (char= (char text j) #\Space)
        finally (return j)))

(defun code-run-len (text pos ch)
  (loop for j from pos below (length text)
        while (char= (char text j) ch)
        count j))

;;; ============================================================
;;; Блочный AST (plist):
;;;   (:type :document :children ...)
;;;   (:type :paragraph :content raw)      — content рендерится инлайн-парсером
;;;   (:type :heading :level N :content raw)
;;;   (:type :blockquote :children ...)
;;;   (:type :list :ordered T/NIL :start N :items (...))  ; item = плат: :type :item :children
;;;   (:type :code-block :info "..." :content "text")
;;;   (:type :thematic-break)
;;;   (:type :html-block :content ...)
;;; ============================================================

;;; ============================================================
;;; Блок-парсер (рекурсивный, по CommonMark)
;;; ============================================================

(defparameter +code-indent+ 4)

(defun atx-heading (line)
  "Возвращает (level . content-start) если ATX-заголовок, иначе NIL."
  (let* ((i (skip-spaces line 0))
         (n 0))
    (loop while (and (< (+ i n) (length line))
                     (char= (char line (+ i n)) #\#)
                     (< n 6))
          do (incf n))
    (when (and (plusp n)
               (or (>= (+ i n) (length line))
                   (is-space (char line (+ i n)))))
      (cons n (+ i n)))))

(defun setext-underline (line)
  "Возвращает 1 или 2 (уровень) если строка — setext-подчёркивание, иначе NIL."
  (let* ((i (skip-spaces line 0))
         (c (when (< i (length line)) (char line i))))
    (when (and c (or (char= c #\=) (char= c #\-)))
      (let ((ok t))
        (loop for j from (1+ i) below (length line)
              for ch = (char line j)
              do (if (or (char= ch c) (is-space ch))
                     nil
                     (setf ok nil)))
        (when ok (if (char= c #\=) 1 2))))))

(defun thematic-break-p (line)
  (let* ((i (skip-spaces line 0))
         (c (when (< i (length line)) (char line i))))
    (when (and c (or (char= c #\*) (char= c #\-) (char= c #\_)))
      (let ((count 0)
            (valid t))
        (loop for j from i below (length line)
              for ch = (char line j)
              do (cond ((char= ch c) (incf count))
                       ((is-space ch))
                       (t (setf valid nil))))
        (and valid (> count 2))))))

(defun fenced-open (line)
  "Возвращает (char . info-start) для открывающей fence-строки, иначе NIL."
  (let* ((i (skip-spaces line 0))
         (c (when (< i (length line)) (char line i))))
    (when (and c (or (char= c #\`) (char= c #\~)))
      (let ((n (code-run-len line i c)))
        (let ((info-start (skip-spaces line (+ i n))))
          (if (and (char= c #\`)
                   (position #\` line :start info-start))
              nil
              (cons c (+ i n))))))))

(defun fence-close-p (line ch n)
  (let* ((i (skip-spaces line 0))
         (len (length line)))
    (when (< i len)
      (let ((m (code-run-len line i ch)))
        (and (>= m n)
             (loop for k from (+ i m) below len
                   always (is-space (char line k))))))))

(defun blockquote-marker (line)
  "Позиция после '>' (и одного пробела) или NIL."
  (let* ((i (skip-spaces line 0))
         (len (length line)))
    (when (and (< i len) (char= (char line i) #\>))
      (let ((j (1+ i)))
        (when (or (>= j len) (is-space (char line j)))
          (if (and (< j len) (is-space (char line j)))
              (1+ j)
              j))))))

(defun list-marker (line)
  "Возвращает (:bullet . after) или (:ordered . start-num) else NIL."
  (let* ((i (skip-spaces line 0))
         (len (length line)))
    (when (< i len)
      (let ((c (char line i)))
        (cond
          ((or (char= c #\-) (char= c #\+) (char= c #\*))
           (let ((j (1+ i)))
             (when (or (>= j len) (is-space (char line j)))
               (cons :bullet j))))
          ((digit-char-p c)
           (let ((j i))
             (loop while (and (< j len) (digit-char-p (char line j))) do (incf j))
             (when (and (<= (- j i) 9)
                        (< j len)
                        (or (char= (char line j) #\.) (char= (char line j) #\)))
                        (let ((k (1+ j)))
                          (or (>= k len) (is-space (char line k)))))
               (cons :ordered (parse-integer (subseq line i j)))))))))))

(defun same-list-type-p (m1 m2)
  "M — (:bullet . after) или (:ordered . num). Проверка совместимости типов."
  (if (eq (car m1) :bullet)
      (eq (car m2) :bullet)
      (eq (car m2) :ordered)))

(defun list-after-pos (line)
  "Позиция контента после маркера списка (и одного пробела), или NIL."
  (let* ((i (skip-spaces line 0))
         (len (length line)))
    (when (< i len)
      (let ((c (char line i)))
        (cond
          ((or (char= c #\-) (char= c #\+) (char= c #\*))
           (let ((j (1+ i)))
             (when (or (>= j len) (is-space (char line j)))
               (if (and (< j len) (is-space (char line j))) (1+ j) j))))
          ((digit-char-p c)
           (let ((j i))
             (loop while (and (< j len) (digit-char-p (char line j))) do (incf j))
             (when (and (<= (- j i) 9)
                        (< j len)
                        (or (char= (char line j) #\.) (char= (char line j) #\)))
                        (let ((k (1+ j)))
                          (or (>= k len) (is-space (char line k)))))
               (if (and (< (1+ j) len) (is-space (char line (1+ j))))
                   (+ j 2)
                   (1+ j))))))))))

(defun link-ref-def (line)
  "Парсит [label]: url \"title\" → (label url title), иначе NIL."
  (let* ((i (skip-spaces line 0))
         (len (length line)))
    (when (and (< i len) (char= (char line i) #\[))
      (let ((close (position #\] line :start (1+ i))))
        (when (and close (<= (+ close 2) len)
                   (char= (char line (1+ close)) #\:))
          (let* ((label (trim-str (subseq line (1+ i) close)))
                 (rest (skip-spaces line (+ close 2))))
            (when (and rest (< rest len))
              (let ((url-end (loop for j from rest below len
                                   while (not (is-space (char line j)))
                                   finally (return j))))
                (let ((url (subseq line rest url-end))
                      (tail (trim-str (subseq line (min url-end len))))
                      (title nil))
                  (when (and (> (length tail) 1)
                             (let ((cc (char tail 0)))
                               (or (char= cc #\") (char= cc #\') (char= cc #\()))
                            (let ((close-c (if (char= (char tail 0) #\() #\) (char tail 0))))
                              (let ((tend (position close-c tail :start 1)))
                                (when tend
                                  (setf title (subseq tail 1 tend))
                                  (when (is-blank-str (subseq tail (1+ tend)))
                                    (return-from link-ref-def
                                      (list (string-downcase label) url title)))))))
                  (return-from link-ref-def
                    (list (string-downcase label) url nil))))))))))))

(defun html-block-line-p (line)
  "T если строка начинается с HTML-тега/комментария (упрощённый типы 1-6).
   Весь блок до пустой строки считается HTML-блоком."
  (let* ((i (skip-spaces line 0))
         (len (length line)))
    (when (< i len)
      (let ((c (char line i)))
        (cond
          ((prefix-p line "<!--" i)
           (let ((end (search "-->" line :start2 (+ i 4))))
             (when end t)))
          ((and (< (1+ i) len) (char= (char line (1+ i)) #\/))
           (let ((j (+ i 2)))
             (when (and (< j len) (alpha-char-p (char line j)))
               (loop while (and (< j len)
                                (or (alphanumericp (char line j))
                                    (char= (char line j) #\-)))
                     do (incf j))
               (and (< j len) (char= (char line j) #\>) t))))
          ((alpha-char-p c)
           (let ((j (1+ i)))
             (when (and (< j len)
                        (or (alpha-char-p (char line j))
                            (char= (char line j) #\Space)
                            (char= (char line j) #\/)
                            (char= (char line j) #\>)))
               (loop for k from j below len
                     for ch = (char line k)
                     do (cond ((char= ch #\>) (return t))
                              ((char= ch #\<) (return nil))))))))))))

;;; ============================================================
;;; parse-blocks-impl — рекурсивный парсер строк
;;; => (values blocks remaining-lines refs)
;;; Каждый тип блока — отдельная функция < 40 строк.
;;; ============================================================

(defun parse-fenced-code (lines n i f)
  "Fenced code block: возвращает (values block new-i)."
  (let* ((ch (car f))
         (fence-start (skip-spaces (nth i lines) 0))
         (fence-len (code-run-len (nth i lines) fence-start ch))
         (info (trim-str (subseq (nth i lines) (cdr f))))
         (code '()))
    (incf i)
    (loop while (< i n)
          for l = (nth i lines)
          do (if (fence-close-p l ch fence-len)
                 (progn (incf i) (return))
                 (progn (push l code) (incf i))))
    (values (list :type :code-block :info info
                  :content (concatenate 'string
                                        (if code (join-lines (nreverse code)) "")
                                        *nl*))
            i)))

(defun parse-indented-code (lines n i)
  "Indented code block (4 пробела). (values block new-i)."
  (let ((code '()))
    (loop while (< i n)
          for l = (nth i lines)
          for ls = (leading-spaces l)
          do (cond
               ((and (> ls 0) (< ls +code-indent+)) (return))
               ((is-blank-str l) (push "" code) (incf i))
               (t (let ((cut (if (>= ls +code-indent+) +code-indent+ 0)))
                    (push (subseq l cut) code)
                    (incf i)))))
    (values (list :type :code-block :info ""
                  :content (join-lines (nreverse code)))
            i)))

(defun parse-blockquote (lines n i refs)
  "Blockquote: собирает строки '> ', рекурсивно парсит. (values block new-i new-refs)."
  (let ((inner '())
        (pending-blank nil))
    (loop while (< i n)
          for l = (nth i lines)
          for m = (blockquote-marker l)
          do (if m
                 (progn (when pending-blank
                          (push "" inner)
                          (setf pending-blank nil))
                        (push (subseq l m) inner)
                        (incf i))
                 (if (is-blank-str l)
                     (progn (setf pending-blank t) (incf i))
                     (if inner
                         (progn (push l inner) (incf i))
                         (return)))))
    (multiple-value-bind (children _ _refs2)
        (parse-blocks-impl (nreverse inner) 0 refs)
      (declare (ignore _))
      (values (list :type :blockquote :children children) i _refs2))))

(defun parse-list (lines n i)
  "Список: собирает элементы (item-lines...). (values type start-num items new-i).
   Каждый элемент — список своих строк в обратном порядке (reverse)."
  (let* ((first-marker (list-marker (nth i lines)))
         (type (car first-marker))
         (start-num (if (eq type :ordered) (cdr first-marker) 1))
         (cont-indent 2)
         (items '())
         (cur nil))
    (loop named list-loop while (< i n)
          for l = (nth i lines)
          for m = (and (not (is-blank-str l)) (list-marker l))
          do (cond
((and m (same-list-type-p first-marker m))
                 (let ((after (list-after-pos l)))
                   (setf cur (list (subseq l after)))
                   (push cur items))
                 (incf i))
               ((is-blank-str l)
                (when cur (push "" cur))
                (incf i))
               ((>= (leading-spaces l) cont-indent)
                (when cur (push l cur))
                (incf i))
               (t (return-from list-loop))))
    (values type start-num (nreverse items) i)))

(defun parse-list-items (items refs)
  "Рекурсивно парсит элементы списка в :item блоки. (values item-blocks new-refs)."
  (let ((item-blocks '()))
    (dolist (il items)
      (setf il (reverse il))
      (let ((trimmed (loop while (and il (is-blank-str (car il)))
                           do (pop il)
                           finally (return il))))
        (multiple-value-bind (child-blocks remaining _refs2)
            (parse-blocks-impl trimmed 0 refs)
          (declare (ignore remaining))
          (setf refs _refs2)
          (push (list :type :item :children child-blocks) item-blocks))))
    (values (nreverse item-blocks) refs)))

(defun parse-html-block (lines n i)
  "HTML-блок до пустой строки. (values block new-i)."
  (let ((html '()))
    (loop while (< i n)
          for l = (nth i lines)
          do (if (is-blank-str l)
                 (return)
                 (progn (push l html) (incf i))))
    (values (list :type :html-block :content (join-lines (nreverse html))) i)))

(defun parse-paragraph (lines n i)
  "Параграф или setext-заголовок. (values block new-i). Block может быть NIL."
  (let ((para '())
        (end-para nil)
        (result nil))
    (labels ((emit-para ()
               (when (and (null result) para)
                 (setf result
                       (list :type :paragraph
                             :content (join-lines (nreverse para)))))))
      (loop while (and (not end-para) (< i n))
            for l = (nth i lines)
            do (cond
                 ((is-blank-str l)
                  (incf i)
                  (setf end-para t))
                 ((and para (setext-underline l)
                       (not (thematic-break-p l)))
                  (let ((lvl (setext-underline l)))
                    (setf result
                          (list :type :heading :level lvl
                                :content (join-lines (nreverse para))))
                    (setf end-para t)
                    (incf i)))
                 ((and para (thematic-break-p l))
                  (setf end-para t))
                 (t
                  (push l para)
                  (incf i))))
      (emit-para)
      (values result i))))

(defun parse-blocks-impl (lines indent &optional (refs (make-hash-table :test #'equal)))
  (let ((blocks '())
        (i 0)
        (n (length lines)))
    (labels
        ((emit (b) (push b blocks))
         (at (idx) (and (< idx n) (nth idx lines)))
         (content-of (line)
           (if (plusp indent)
               (let ((ls (leading-spaces line)))
                 (if (>= ls indent)
                     (subseq line indent)
                     line))
               line)))
      (loop while (< i n)
            do (let* ((line (at i))
                      (content (content-of line)))
                 (cond
                   ;; ---- blank
                   ((is-blank-str content)
                    (incf i))

                   ;; ---- thematic break
                   ((thematic-break-p content)
                    (emit (list :type :thematic-break))
                    (incf i))

                   ;; ---- ATX heading
                   ((atx-heading content)
                    (let* ((h (atx-heading content))
                           (level (car h))
                           (raw (strip-trailing-heading-marks
                                 (trim-str (subseq content (cdr h))))))
                      (emit (list :type :heading :level level :content raw))
                      (incf i)))

                   ;; ---- fenced code
                   ((fenced-open content)
                    (multiple-value-bind (block new-i)
                        (parse-fenced-code lines n i (fenced-open content))
                      (emit block)
                      (setf i new-i)))

                   ;; ---- indented code
                   ((>= (leading-spaces content) +code-indent+)
                    (multiple-value-bind (block new-i)
                        (parse-indented-code lines n i)
                      (emit block)
                      (setf i new-i)))

                   ;; ---- blockquote
                   ((blockquote-marker line)
                    (multiple-value-bind (block new-i new-refs)
                        (parse-blockquote lines n i refs)
                      (emit block)
                      (setf i new-i)
                      (setf refs new-refs)))

                   ;; ---- list
                   ((and (not (is-blank-str content))
                         (list-marker content))
                    (multiple-value-bind (ltype start-num items new-i)
                        (parse-list lines n i)
                      (multiple-value-bind (item-blocks new-refs)
                          (parse-list-items items refs)
                        (emit (list :type :list
                                    :ordered (eq ltype :ordered)
                                    :start start-num
                                    :items item-blocks))
                        (setf refs new-refs))
                      (setf i new-i)))

                   ;; ---- link reference definition
                   ((link-ref-def content)
                    (let ((def (link-ref-def content)))
                      (setf (gethash (car def) refs) (cdr def))
                      (incf i)))

                   ;; ---- html block
                   ((html-block-line-p content)
                    (multiple-value-bind (block new-i)
                        (parse-html-block lines n i)
                      (emit block)
                      (setf i new-i)))

                   ;; ---- paragraph / setext
                   (t
                    (multiple-value-bind (block new-i)
                        (parse-paragraph lines n i)
                      (when block
                        (emit block))
                      (setf i new-i))))))
      (values (reverse blocks) (when (< i n) (nthcdr i lines)) refs))))

(defun strip-trailing-heading-marks (raw)
  "Убрать закрывающие ### (должен быть пробел перед ними)."
  (let* ((trimmed (string-right-trim " #" raw))
         (before (string-trim " #" raw)))
    (if (and (> (length before) 0)
             (string= trimmed
                      (string-right-trim " "
                       (subseq before 0 (- (length before)
                                           (length (string-right-trim " #" before)))))))
        before
        (let ((last-hash (position #\# raw :from-end t)))
          (if (and last-hash
                   (loop for j from last-hash below (length raw)
                         always (char= (char raw j) #\#))
                   (plusp last-hash)
                   (is-space (char raw (1- last-hash))))
              (trim-str (subseq raw 0 last-hash))
              trimmed)))))

;;; ============================================================
;;; Инлайн-парсер
;;; ============================================================

;;; Узлы: строка (текст), (:emph child0 child1...) (:strong ...)
;;;   (:code "text") (:link url title child...) (:image url title alt)
;;;   (:autolink raw) (:raw-html tag) (:softbreak) (:hardbreak)

(defun parse-inline-lex (text &optional no-links)
  "Разбивает TEXT на лексемы: строки, (:delim char n), (:code s), (:link ...),
   (:image ...), (:autolink s), (:raw-html s), :softbreak, :hardbreak.
   При NO-LINKS '['/'!'/'(' не трактуются как начало ссылки (для label'ов)."
  (let ((tokens '())
        (i 0)
        (len (length text)))
    (labels ((push-text (s)
               (when (plusp (length s)) (push s tokens)))
             (adv (n) (incf i n)))
      (loop while (< i len)
            do (let ((c (char text i)))
                 (cond
                   ;; backslash escape
                   ((and (char= c #\\) (< (1+ i) len)
                         (char= (char text (1+ i)) #\Newline))
                    (push :hardbreak tokens)
                    (adv 2))
                   ((and (char= c #\\) (< (1+ i) len)
                         (ascii-punct-p (char text (1+ i))))
                    (push-text (string (char text (1+ i))))
                    (adv 2))
                   ((char= c #\\)
                    (push-text "\\") (adv 1))
                   ;; blank line
                   ((is-blank-str (subseq text i))
                    nil)
                   ;; line break
                   ((char= c #\Newline)
                    (push :softbreak tokens)
                    (adv 1))
                   ;; hard break (2+ пробела перед новымline)
                   ((and (char= c #\Space)
                         (> (code-run-len text i #\Space) 1)
                         (< (trailing-spaces-end text i) len)
                         (char= (char text (trailing-spaces-end text i)) #\Newline))
                    (push :hardbreak tokens)
                    (setf i (1+ (trailing-spaces-end text i))))
                   ;; code span
                   ((char= c #\`)
                    (let* ((tick-len (code-run-len text i #\`))
                           (j (+ i tick-len))
                           (close-end nil)
                           (found nil))
                      (loop while (< j len)
                            for run = (code-run-len text j #\`)
                            do (if (= run tick-len)
                                   (progn
                                     (setf close-end (+ j run))
                                     (setf found t)
                                     (setf j len)
                                     (return))
                                   (setf j (+ j run (if (zerop run) 1 0)))))
                      (if found
                          (progn
                            (push (list :code
                                        (code-normalize (subseq text (+ i tick-len) (- close-end tick-len))))
                                  tokens)
                            (setf i close-end))
                          (progn (push-text (subseq text i (min (+ i tick-len) len)))
                                 (adv tick-len)))))
                   ;; emphasis
                   ((or (char= c #\*) (char= c #\_))
                    (let ((n (code-run-len text i c)))
                      (push (list :delim c n) tokens)
                      (adv n)))
                   ;; link / image
                   ((and (not no-links) (char= c #\[))
                    (let ((res (parse-inline-link text i)))
                      (if res
                          (progn (destructuring-bind (next . node) res
                                   (push node tokens)
                                   (setf i next)))
                          (progn (push-text "[") (adv 1)))))
                   ((and (not no-links) (char= c #\!)
                         (< (1+ i) len)
                         (char= (char text (1+ i)) #\[))
                    (let ((res (parse-inline-link text (1+ i) t)))
                      (if res
                          (progn (destructuring-bind (next . node) res
                                   (push node tokens)
                                   (setf i next)))
                          (progn (push-text "![") (adv 2)))))
                   ((char= c #\])
                    (push-text "]") (adv 1))
                   ;; autolink / raw html
                   ((char= c #\<)
                    (let ((auto (parse-autolink text i)))
                      (if auto
                          (progn (push (cdr auto) tokens) (setf i (car auto)))
                          (let ((tag-end (parse-html-tag text i)))
                            (if tag-end
                                (progn (push (list :raw-html (subseq text i tag-end)) tokens)
                                       (setf i tag-end))
                                (progn (push-text "<") (adv 1)))))))
                   (t
                    (push-text (string c))
                    (adv 1)))))
      (nreverse tokens))))

(defun code-normalize (s)
  "Нормализация code-span: убрать по одному ведущему/замыкающему пробелу,
   заменить переносы на пробелы."
  (let* ((t1 (substitute #\Space (code-char 10) s))
         (t2 (string-trim " " t1)))
    (if (loop for c across t2 always (or (char= c #\Space) (char= c #\Tab)))
        ""
        t2)))

(defun parse-label-inline (s)
  "Inline-разбор label'а ссылки: без вложенных ссылок, с эмфазой."
  (parse-emphasis (parse-inline-lex s t)))

(defun parse-inline-link (text open &optional is-image)
  "OPEN — позиция '['. Возвращает (cons next-pos node) или NIL."
  (let* ((len (length text))
         (label-end (position #\] text :start (1+ open))))
    (unless label-end (return-from parse-inline-link nil))
    (let ((label (trim-str (subseq text (1+ open) label-end)))
          (after (1+ label-end)))
      (cond
        ((and (< after len) (char= (char text after) #\())
         (let ((paren (matching-paren text after)))
           (when paren
             (let* ((inner (subseq text (1+ after) paren))
                    (inner-trim (trim-str inner))
                    (space-idx (position #\Space inner-trim)))
               (if (and space-idx (plusp (1+ space-idx)))
                   (let ((url (subseq inner-trim 0 space-idx))
                         (title (string-trim " \"" (subseq inner-trim (1+ space-idx)))))
                     (return-from parse-inline-link
                       (cons (1+ paren)
                             (if is-image
                                 (list :image url title label)
                                 (cons :link (cons url (cons title (parse-label-inline label))))))))
                   (return-from parse-inline-link
                     (cons (1+ paren)
                           (if is-image
                               (list :image inner-trim "" label)
                               (cons :link (cons inner-trim (cons "" (parse-label-inline label)))))))))))))
        (t
         ;; reference link [label][ref] или [label]
         (let ((ref-len 0)
               (ref nil))
           (when (and (< after len) (char= (char text after) #\[))
             (let ((ref-end (position #\] text :start (1+ after))))
               (when ref-end
                 (setf ref (subseq text (1+ after) ref-end)
                       ref-len (- ref-end after 1)))))
           (let ((key (if (and ref (plusp (length (trim-str ref))))
                          (string-downcase (trim-str ref))
                          (string-downcase label))))
              (return-from parse-inline-link
                (cons (+ after (if ref-len (+ ref-len 2) 0))
                      (if is-image
                          (list :image (concatenate 'string "#" key) "" label)
                          (cons :link (cons (concatenate 'string "#" key)
                                            (cons "" (parse-label-inline label)))))))))))))

(defun matching-paren (text open)
  (let ((depth 0))
    (loop for j from open below (length text)
          for c = (char text j)
          do (cond ((char= c #\() (incf depth))
                   ((char= c #\))
                    (decf depth)
                    (when (zerop depth) (return j)))
                   ((char= c #\\)
                    (if (< (1+ j) (length text)) (incf j))))
          finally (return nil))))

(defun parse-autolink (text pos)
  (let* ((len (length text))
         (close (position #\> text :start (1+ pos))))
    (when close
      (let ((inner (subseq text (1+ pos) close)))
        (cond
          ((or (prefix-p inner "http://" 0)
               (prefix-p inner "https://" 0)
               (prefix-p inner "ftp://" 0))
           (cons (1+ close) (list :autolink inner)))
          ((and (position #\@ inner)
                (not (position #\Space inner)))
           (cons (1+ close) (list :autolink (concatenate 'string "mailto:" inner))))
          (t nil))))))

(defun parse-html-tag (text pos)
  (let ((len (length text)))
    (cond
      ((prefix-p text "<!--" pos)
       (let ((end (search "-->" text :start2 (+ pos 4))))
         (when end (+ end 3))))
      ((and (< (1+ pos) len) (char= (char text (1+ pos)) #\/))
       (let ((j (+ pos 2)))
         (when (and (< j len) (alpha-char-p (char text j)))
           (loop while (and (< j len)
                            (or (alphanumericp (char text j))
                                (char= (char text j) #\-)))
                 do (incf j))
           (when (and (< j len) (char= (char text j) #\>))
             (1+ j)))))
      ((and (< (1+ pos) len) (alpha-char-p (char text (1+ pos))))
       (let ((in-quote nil) (qchar nil))
         (loop for k from (+ pos 2) below len
               for ch = (char text k)
               do (cond
                    ((and in-quote (char= ch qchar)) (setf in-quote nil))
                    ((or (char= ch #\") (char= ch #\')) (setf in-quote t qchar ch))
                    ((and (not in-quote) (char= ch #\>)) (return (1+ k))))
               finally (return nil)))))))

;;; ============================================================
;;; Emphasis — переделка :delim-серий в :emph/:strong
;;; ============================================================

;;; Двухпроходный алгоритм в духе CommonMark:
;;;   1) проход слева направо со стеком открытых делимитеров; каждый
;;;      закрывающий матчит ближайший открытый с тем же символом
;;;      (flanking-правила), записывается match (opener closer k),
;;;      делимитеры укорачиваются на k;
;;;   2) построение дерева: фрейм = открытый регион, при закрытии
;;;      содержимое собирается в :emph/:strong. Несколько match'ей
;;;      одного opener/closer дают вложенность (***both*** → em<strong>).

(defun delim-token-p (tok)
  (and (listp tok) (eq (car tok) :delim)))

(defun token-char-before (tokens j)
  "Символ исходного текста перед токеном j: :ws для начала строки/переносов,
   символ для text/delim, :word для прочих узлов."
  (if (zerop j)
      :ws
      (let ((prev (aref tokens (1- j))))
        (cond
          ((stringp prev) (char prev (1- (length prev))))
          ((and (listp prev) (eq (car prev) :delim)) (second prev))
          ((or (eq prev :softbreak) (eq prev :hardbreak)) :ws)
          (t :word)))))

(defun token-char-after (tokens j)
  "Символ исходного текста после токена j."
  (if (>= (1+ j) (length tokens))
      :ws
      (let ((next (aref tokens (1+ j))))
        (cond
          ((stringp next) (char next 0))
          ((and (listp next) (eq (car next) :delim)) (second next))
          ((or (eq next :softbreak) (eq next :hardbreak)) :ws)
          (t :word)))))

(defun char-ws-p (x)
  "Unicode whitespace по CommonMark 0.31.2: Zs-категория + TAB/LF/FF/CR."
  (or (eq x :ws)
      (and (characterp x)
           (let ((cp (char-code x)))
             (or (= cp 9) (= cp 10) (= cp 12) (= cp 13)
                 (= cp 32) (= cp 160) (= cp 5760)
                 (and (>= cp 8192) (<= cp 8202))
                 (= cp 8239) (= cp 8287) (= cp 12288))))))

(defparameter *unicode-punct-ranges*
  '((#x00A1 #x00A9) (#x00AB #x00AC) (#x00AE #x00B1) (#x00B4 #x00B4) (#x00B6 #x00B8) (#x00BB #x00BB) (#x00BF #x00BF) (#x00D7 #x00D7) (#x00F7 #x00F7) (#x02C2 #x02C5) (#x02D2 #x02DF) (#x02E5 #x02EB)
    (#x02ED #x02ED) (#x02EF #x02FF) (#x0375 #x0375) (#x037E #x037E) (#x0384 #x0385) (#x0387 #x0387) (#x03F6 #x03F6) (#x0482 #x0482) (#x055A #x055F) (#x0589 #x058A) (#x058D #x058F) (#x05BE #x05BE)
    (#x05C0 #x05C0) (#x05C3 #x05C3) (#x05C6 #x05C6) (#x05F3 #x05F4) (#x0606 #x060F) (#x061B #x061B) (#x061D #x061F) (#x066A #x066D) (#x06D4 #x06D4) (#x06DE #x06DE) (#x06E9 #x06E9) (#x06FD #x06FE)
    (#x0700 #x070D) (#x07F6 #x07F9) (#x07FE #x07FF) (#x0830 #x083E) (#x085E #x085E) (#x0888 #x0888) (#x0964 #x0965) (#x0970 #x0970) (#x09F2 #x09F3) (#x09FA #x09FB) (#x09FD #x09FD) (#x0A76 #x0A76)
    (#x0AF0 #x0AF1) (#x0B70 #x0B70) (#x0BF3 #x0BFA) (#x0C77 #x0C77) (#x0C7F #x0C7F) (#x0C84 #x0C84) (#x0D4F #x0D4F) (#x0D79 #x0D79) (#x0DF4 #x0DF4) (#x0E3F #x0E3F) (#x0E4F #x0E4F) (#x0E5A #x0E5B)
    (#x0F01 #x0F17) (#x0F1A #x0F1F) (#x0F34 #x0F34) (#x0F36 #x0F36) (#x0F38 #x0F38) (#x0F3A #x0F3D) (#x0F85 #x0F85) (#x0FBE #x0FC5) (#x0FC7 #x0FCC) (#x0FCE #x0FDA) (#x104A #x104F) (#x109E #x109F)
    (#x10FB #x10FB) (#x1360 #x1368) (#x1390 #x1399) (#x1400 #x1400) (#x166D #x166E) (#x169B #x169C) (#x16EB #x16ED) (#x1735 #x1736) (#x17D4 #x17D6) (#x17D8 #x17DB) (#x1800 #x180A) (#x1940 #x1940)
    (#x1944 #x1945) (#x19DE #x19FF) (#x1A1E #x1A1F) (#x1AA0 #x1AA6) (#x1AA8 #x1AAD) (#x1B5A #x1B6A) (#x1B74 #x1B7E) (#x1BFC #x1BFF) (#x1C3B #x1C3F) (#x1C7E #x1C7F) (#x1CC0 #x1CC7) (#x1CD3 #x1CD3)
    (#x1FBD #x1FBD) (#x1FBF #x1FC1) (#x1FCD #x1FCF) (#x1FDD #x1FDF) (#x1FED #x1FEF) (#x1FFD #x1FFE) (#x2010 #x2027) (#x2030 #x205E) (#x207A #x207E) (#x208A #x208E) (#x20A0 #x20C0) (#x2100 #x2101)
    (#x2103 #x2106) (#x2108 #x2109) (#x2114 #x2114) (#x2116 #x2118) (#x211E #x2123) (#x2125 #x2125) (#x2127 #x2127) (#x2129 #x2129) (#x212E #x212E) (#x213A #x213B) (#x2140 #x2144) (#x214A #x214D)
    (#x214F #x214F) (#x218A #x218B) (#x2190 #x2426) (#x2440 #x244A) (#x249C #x24E9) (#x2500 #x2775) (#x2794 #x2B73) (#x2B76 #x2B95) (#x2B97 #x2BFF) (#x2CE5 #x2CEA) (#x2CF9 #x2CFC) (#x2CFE #x2CFF)
    (#x2D70 #x2D70) (#x2E00 #x2E2E) (#x2E30 #x2E5D) (#x2E80 #x2E99) (#x2E9B #x2EF3) (#x2F00 #x2FD5) (#x2FF0 #x2FFB) (#x3001 #x3004) (#x3008 #x3020) (#x3030 #x3030) (#x3036 #x3037) (#x303D #x303F)
    (#x309B #x309C) (#x30A0 #x30A0) (#x30FB #x30FB) (#x3190 #x3191) (#x3196 #x319F) (#x31C0 #x31E3) (#x3200 #x321E) (#x322A #x3247) (#x3250 #x3250) (#x3260 #x327F) (#x328A #x32B0) (#x32C0 #x33FF)
    (#x4DC0 #x4DFF) (#xA490 #xA4C6) (#xA4FE #xA4FF) (#xA60D #xA60F) (#xA673 #xA673) (#xA67E #xA67E) (#xA6F2 #xA6F7) (#xA700 #xA716) (#xA720 #xA721) (#xA789 #xA78A) (#xA828 #xA82B) (#xA836 #xA839)
    (#xA874 #xA877) (#xA8CE #xA8CF) (#xA8F8 #xA8FA) (#xA8FC #xA8FC) (#xA92E #xA92F) (#xA95F #xA95F) (#xA9C1 #xA9CD) (#xA9DE #xA9DF) (#xAA5C #xAA5F) (#xAA77 #xAA79) (#xAADE #xAADF) (#xAAF0 #xAAF1)
    (#xAB5B #xAB5B) (#xAB6A #xAB6B) (#xABEB #xABEB) (#xFB29 #xFB29) (#xFBB2 #xFBC2) (#xFD3E #xFD4F) (#xFDCF #xFDCF) (#xFDFC #xFDFF) (#xFE10 #xFE19) (#xFE30 #xFE52) (#xFE54 #xFE66) (#xFE68 #xFE6B)
    (#xFF01 #xFF0F) (#xFF1A #xFF20) (#xFF3B #xFF40) (#xFF5B #xFF65) (#xFFE0 #xFFE6) (#xFFE8 #xFFEE) (#xFFFC #xFFFD) (#x10100 #x10102) (#x10137 #x1013F) (#x10179 #x10189) (#x1018C #x1018E) (#x10190 #x1019C)
    (#x101A0 #x101A0) (#x101D0 #x101FC) (#x1039F #x1039F) (#x103D0 #x103D0) (#x1056F #x1056F) (#x10857 #x10857) (#x10877 #x10878) (#x1091F #x1091F) (#x1093F #x1093F) (#x10A50 #x10A58) (#x10A7F #x10A7F) (#x10AC8 #x10AC8)
    (#x10AF0 #x10AF6) (#x10B39 #x10B3F) (#x10B99 #x10B9C) (#x10EAD #x10EAD) (#x10F55 #x10F59) (#x10F86 #x10F89) (#x11047 #x1104D) (#x110BB #x110BC) (#x110BE #x110C1) (#x11140 #x11143) (#x11174 #x11175) (#x111C5 #x111C8)
    (#x111CD #x111CD) (#x111DB #x111DB) (#x111DD #x111DF) (#x11238 #x1123D) (#x112A9 #x112A9) (#x1144B #x1144F) (#x1145A #x1145B) (#x1145D #x1145D) (#x114C6 #x114C6) (#x115C1 #x115D7) (#x11641 #x11643) (#x11660 #x1166C)
    (#x116B9 #x116B9) (#x1173C #x1173F) (#x1183B #x1183B) (#x11944 #x11946) (#x119E2 #x119E2) (#x11A3F #x11A46) (#x11A9A #x11A9C) (#x11A9E #x11AA2) (#x11C41 #x11C45) (#x11C70 #x11C71) (#x11EF7 #x11EF8) (#x11FD5 #x11FF1)
    (#x11FFF #x11FFF) (#x12470 #x12474) (#x12FF1 #x12FF2) (#x16A6E #x16A6F) (#x16AF5 #x16AF5) (#x16B37 #x16B3F) (#x16B44 #x16B45) (#x16E97 #x16E9A) (#x16FE2 #x16FE2) (#x1BC9C #x1BC9C) (#x1BC9F #x1BC9F) (#x1CF50 #x1CFC3)
    (#x1D000 #x1D0F5) (#x1D100 #x1D126) (#x1D129 #x1D164) (#x1D16A #x1D16C) (#x1D183 #x1D184) (#x1D18C #x1D1A9) (#x1D1AE #x1D1EA) (#x1D200 #x1D241) (#x1D245 #x1D245) (#x1D300 #x1D356) (#x1D6C1 #x1D6C1) (#x1D6DB #x1D6DB)
    (#x1D6FB #x1D6FB) (#x1D715 #x1D715) (#x1D735 #x1D735) (#x1D74F #x1D74F) (#x1D76F #x1D76F) (#x1D789 #x1D789) (#x1D7A9 #x1D7A9) (#x1D7C3 #x1D7C3) (#x1D800 #x1D9FF) (#x1DA37 #x1DA3A) (#x1DA6D #x1DA74) (#x1DA76 #x1DA83)
    (#x1DA85 #x1DA8B) (#x1E14F #x1E14F) (#x1E2FF #x1E2FF) (#x1E95E #x1E95F) (#x1ECAC #x1ECAC) (#x1ECB0 #x1ECB0) (#x1ED2E #x1ED2E) (#x1EEF0 #x1EEF1) (#x1F000 #x1F02B) (#x1F030 #x1F093) (#x1F0A0 #x1F0AE) (#x1F0B1 #x1F0BF)
    (#x1F0C1 #x1F0CF) (#x1F0D1 #x1F0F5) (#x1F10D #x1F1AD) (#x1F1E6 #x1F202) (#x1F210 #x1F23B) (#x1F240 #x1F248) (#x1F250 #x1F251) (#x1F260 #x1F265) (#x1F300 #x1F6D7) (#x1F6DD #x1F6EC) (#x1F6F0 #x1F6FC) (#x1F700 #x1F773)
    (#x1F780 #x1F7D8) (#x1F7E0 #x1F7EB) (#x1F7F0 #x1F7F0) (#x1F800 #x1F80B) (#x1F810 #x1F847) (#x1F850 #x1F859) (#x1F860 #x1F887) (#x1F890 #x1F8AD) (#x1F8B0 #x1F8B1) (#x1F900 #x1FA53) (#x1FA60 #x1FA6D) (#x1FA70 #x1FA74)
    (#x1FA78 #x1FA7C) (#x1FA80 #x1FA86) (#x1FA90 #x1FAAC) (#x1FAB0 #x1FABA) (#x1FAC0 #x1FAC5) (#x1FAD0 #x1FAD9) (#x1FAE0 #x1FAE7) (#x1FAF0 #x1FAF6) (#x1FB00 #x1FB92) (#x1FB94 #x1FBCA)))

(defun unicode-punct-p (x)
  (and (characterp x)
       (let ((cp (char-code x)))
         (loop for (lo hi) in *unicode-punct-ranges*
               when (and (>= cp lo) (<= cp hi)) return t))))

(defun char-punct-p (x)
  (and (characterp x)
       (or (ascii-punct-p x)
           (unicode-punct-p x))))

(defun left-flanking-p (tokens j)
  (let ((after (token-char-after tokens j))
        (before (token-char-before tokens j)))
    (and (not (char-ws-p after))
         (or (not (char-punct-p after))
             (char-ws-p before)
             (char-punct-p before)))))

(defun right-flanking-p (tokens j)
  (let ((after (token-char-after tokens j))
        (before (token-char-before tokens j)))
    (and (not (char-ws-p before))
         (or (not (char-punct-p before))
             (char-ws-p after)
             (char-punct-p after)))))

(defun emphasis-can-open-p (tokens j)
  (let* ((c (second (aref tokens j)))
         (lf (left-flanking-p tokens j))
         (rf (right-flanking-p tokens j)))
    (if (char= c #\_)
        (and lf (or (not rf) (char-punct-p (token-char-before tokens j))))
        lf)))

(defun emphasis-can-close-p (tokens j)
  (let* ((c (second (aref tokens j)))
         (lf (left-flanking-p tokens j))
         (rf (right-flanking-p tokens j)))
    (if (char= c #\_)
        (and rf (or (not lf) (char-punct-p (token-char-after tokens j))))
        rf)))

(defun emphasis-match-forbidden-p (tokens leftover oi j)
  "Мод-3 rule (CommonMark 0.31.2, 'Emphasis and strong emphasis'):
   если один из делимитеров может и открывать, и закрывать, а (olen+clen)%3==0
   при clen%3!=0 — пара opener/closer эмфазу НЕ образует."
  (let ((closer-can-open (emphasis-can-open-p tokens j))
        (opener-can-close (emphasis-can-close-p tokens oi))
        (olen (aref leftover oi))
        (clen (aref leftover j)))
    (and (or closer-can-open opener-can-close)
         (not (zerop (mod clen 3)))
         (zerop (mod (+ olen clen) 3)))))

(defun find-opener (tokens leftover stack j)
  "Ближайший (самый свежий) открытый делимитер с тем же символом,
   не запрещённый мод-3 правилом (ищем дальше/старше при запрете)."
  (let ((c (second (aref tokens j))))
    (loop for idx in stack
          when (and (char= (second (aref tokens idx)) c)
                    (not (emphasis-match-forbidden-p tokens leftover idx j)))
            return idx)))

(defun drop-above-incl (stack idx)
  "Убрать из стека элементы выше IDX и сам IDX."
  (let ((tail (member idx stack)))
    (if tail (cdr tail) nil)))

(defun literal-delim (c n)
  (make-string n :initial-element c))

(defun find-emphasis-matches (tokens)
  "Проход 1: все пары (opener closer k). Возвращает:
   opener-matches — массив индекс→список (closer . k), хронологический порядок (внешний сначала);
   leftover — массив индекс→остаток символов делимитера."
  (let* ((n (length tokens))
         (leftover (make-array n :initial-element 0))
         (opener-matches (make-array n :initial-element nil))
         (stack '()))
    (loop for j from 0 below n
          for tok = (aref tokens j)
          when (delim-token-p tok)
            do (setf (aref leftover j) (third tok)))
    (loop for j from 0 below n
          for tok = (aref tokens j)
          do (when (delim-token-p tok)
               (loop while (and (delim-token-p (aref tokens j))
                                (plusp (aref leftover j))
                                (emphasis-can-close-p tokens j)
                                (find-opener tokens leftover stack j))
                     do (let* ((oi (find-opener tokens leftover stack j))
                               (no (aref leftover oi))
                               (nc (aref leftover j))
                               (k (if (and (>= no 2) (>= nc 2)) 2 1)))
                          (push (cons j k) (aref opener-matches oi))
                          (setf (aref leftover oi) (- no k))
                          (setf (aref leftover j) (- nc k))
                          (setf stack (drop-above-incl stack oi))
                          (when (plusp (aref leftover oi))
                            (push oi stack))))
               (when (and (delim-token-p (aref tokens j))
                          (plusp (aref leftover j))
                          (emphasis-can-open-p tokens j))
                 (push j stack))))
    (loop for j from 0 below n
          when (aref opener-matches j)
            do (setf (aref opener-matches j) (nreverse (aref opener-matches j))))
    (values opener-matches leftover)))

(defun build-emphasis-tree (tokens opener-matches leftover)
  "Проход 2: собрать :emph/:strong узлы по match'ам."
  (let ((root (list nil nil nil))
        (frames '()))    ; (opener-idx pending-matches children)
    (labels ((emit (node)
               (let ((frame (or (car frames) root)))
                 (push node (third frame)))))
      (loop for j from 0 below (length tokens)
            for tok = (aref tokens j)
            do
            (loop while (and frames
                             (let ((pm (second (car frames))))
                               (and pm (= (car (car pm)) j))))
                  do (let* ((frame (car frames))
                            (matches (second frame))
                            (m (car matches))
                            (k (cdr m))
                            (children (nreverse (third frame)))
                            (node (if (= k 1)
                                      (cons :emph children)
                                      (cons :strong children))))
                       (if (cdr matches)
                           (progn (setf (third frame) (list node))
                                  (setf (second frame) (cdr matches)))
                           (progn (pop frames)
                                  (emit node)))))
            (if (delim-token-p tok)
                (let ((l (aref leftover j))
                      (oms (aref opener-matches j)))
                  (when (plusp l)
                    (emit (literal-delim (second tok) l)))
                  (when oms
                    (push (list j oms '()) frames)))
                (emit tok))))
      (nreverse (third root))))

(defun parse-emphasis (tokens)
  "Tokens → узлы с :emph/:strong. Возвращает список узлов."
  (let ((vec (coerce tokens 'vector)))
    (multiple-value-bind (opener-matches leftover)
        (find-emphasis-matches vec)
      (build-emphasis-tree vec opener-matches leftover))))

;;; ============================================================
;;; HTML-рендер
;;; ============================================================

(defun escape-html (s)
  (let ((out '()))
    (loop for i from 0 below (length s)
          for c = (char s i)
          do (case c
               (#\& (push "&amp;" out))
               (#\< (push "&lt;" out))
               (#\> (push "&gt;" out))
               (#\" (push "&quot;" out))
               (otherwise (push (string c) out))))
    (apply #'concatenate 'string (nreverse out))))

(defun escape-attr (s)
  (let ((out '()))
    (loop for i from 0 below (length s)
          for c = (char s i)
          do (case c
               (#\& (push "&amp;" out))
               (#\< (push "&lt;" out))
               (#\> (push "&gt;" out))
               (#\" (push "&quot;" out))
               (otherwise (push (string c) out))))
    (apply #'concatenate 'string (nreverse out))))

(defun safe-url-p (url)
  (when url
    (let ((lower (string-downcase url)))
      (or
       (loop for scheme in '("http://" "https://" "mailto:" "ftp://" "data:image/"
                             "#" "/" "./" "../")
             thereis (prefix-p lower scheme 0))
       (not (or (search "javascript:" lower)
                (search "vbscript:" lower)))))))

(defun render-inline-node (node)
  (cond
    ((stringp node)
     (escape-html node))
    ((eq node :softbreak) *nl*)
    ((eq node :hardbreak) (concatenate 'string "<br/>" *nl*))
    ((and (listp node) (eq (car node) :emph))
     (concatenate 'string "<em>" (render-inlines (cdr node)) "</em>"))
    ((and (listp node) (eq (car node) :strong))
     (concatenate 'string "<strong>" (render-inlines (cdr node)) "</strong>"))
    ((and (listp node) (eq (car node) :code))
     (concatenate 'string "<code>" (escape-html (second node)) "</code>"))
    ((and (listp node) (eq (car node) :link))
     (let ((url (second node))
           (title (third node))
           (children (cdddr node)))
       (if (safe-url-p (if (prefix-p url "#" 0) (subseq url 1) url))
           (concatenate 'string
                        (format nil "<a href=\"~A\"" (escape-attr url))
                        (if (plusp (length title))
                            (format nil " title=\"~A\"" (escape-attr title))
                            "")
                        ">" (render-inlines children) "</a>")
           (render-inlines children))))
    ((and (listp node) (eq (car node) :image))
     (let ((url (second node))
           (alt (fourth node)))
       (if (safe-url-p url)
           (format nil "<img src=\"~A\" alt=\"~A\"/>" (escape-attr url) (escape-attr alt))
           (escape-html alt))))
    ((and (listp node) (eq (car node) :autolink))
     (let ((u (second node)))
       (if (safe-url-p u)
           (format nil "<a href=\"~A\">~A</a>" (escape-attr u) (escape-html u))
           (escape-html u))))
    ((and (listp node) (eq (car node) :raw-html))
     (escape-html (second node)))
    ((and (listp node) (eq (car node) :delim))
     (make-string (third node) :initial-element (second node)))
    (t (escape-html (format nil "~A" node)))))

(defun render-inlines (nodes)
  (apply #'concatenate 'string
         (loop for n in nodes collect (render-inline-node n))))

(defun render-block (block)
  (let ((out '()))
    (labels ((w (s) (push s out)))
      (case (getf block :type)
        (:paragraph
         (w "<p>")
         (w (render-inlines
             (parse-emphasis (parse-inline-lex (getf block :content)))))
         (w (concatenate 'string "</p>" *nl*)))
        (:heading
         (let ((lvl (getf block :level)))
           (w (format nil "<h~A>" lvl))
           (w (render-inlines
               (parse-emphasis (parse-inline-lex (getf block :content)))))
           (w (concatenate 'string (format nil "</h~A>" lvl) *nl*))))
        (:blockquote
         (w (concatenate 'string "<blockquote>" *nl*))
         (dolist (c (getf block :children)) (w (render-block c)))
         (w (concatenate 'string "</blockquote>" *nl*)))
        (:list
         (w (concatenate 'string (if (getf block :ordered) "<ol>" "<ul>") *nl*))
         (dolist (it (getf block :items)) (w (render-block it)))
         (w (concatenate 'string (if (getf block :ordered) "</ol>" "</ul>") *nl*)))
        (:item
         (w "<li>")
         (let ((blocks (getf block :children)))
           (cond
             ((and (= (length blocks) 1)
                   (eq (getf (car blocks) :type) :paragraph))
              (w (render-inlines
                  (parse-emphasis (parse-inline-lex (getf (car blocks) :content))))))
             (t (dolist (c blocks) (w (render-block c))))))
         (w (concatenate 'string "</li>" *nl*)))
        (:code-block
         (w "<pre><code")
         (let ((info (getf block :info)))
           (when (plusp (length (trim-str info)))
             (let ((lang (first (split-str (trim-str info) #\Space))))
               (w (format nil " class=\"language-~A\"" (string-downcase lang))))))
         (w ">")
         (w (escape-html (getf block :content)))
         (w (concatenate 'string "</code></pre>" *nl*)))
        (:thematic-break (w (concatenate 'string "<hr/>" *nl*)))
        (:html-block (w (escape-html (getf block :content))))
        (otherwise (w ""))))
    (apply #'concatenate 'string (nreverse out))))

(defun split-str (s sep)
  (let ((out '())
        (start 0)
        (len (length s)))
    (loop for i from 0 below len
          for c = (char s i)
          do (when (char= c sep)
               (push (subseq s start i) out)
               (setf start (1+ i))))
    (push (subseq s start) out)
    (nreverse out)))

(defun render-document (blocks)
  (let ((out '()))
    (dolist (b blocks)
      (push (render-block b) out))
    (apply #'concatenate 'string (nreverse out))))

;;; ============================================================
;;; Основной вход
;;; ============================================================

(defun render-to-html (source)
  "Markdown → безопасный HTML."
  (let ((lines (split-lines source)))
    (multiple-value-bind (blocks _refs)
        (parse-blocks-impl lines 0)
      (declare (ignore _refs))
      (render-document blocks))))