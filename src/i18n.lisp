(in-package :lisper)

;;; Интернационализация.
;;;
;;; Языки: *languages* — список поддерживаемых кодов. Словари регистрируются
;;; через register-dict (см. src/i18n-ru.lisp, src/i18n-en.lisp, src/i18n-tr.lisp,
;;; src/i18n-uk.lisp).
;;;
;;; Выбор языка для запроса (по приоритету):
;;;   1. cookie `lang` (явный выбор через /set-lang)
;;;   2. заголовок Accept-Language (среди *languages*)
;;;   3. язык по умолчанию для домена (*domain-languages* по суффиксу Host)
;;;   4. *default-language*
;;;
;;; В рендере используется динамическая переменная *lang* (связывается в
;;; make-app на каждый запрос). Названия страниц не зависят от языка (слаг).

(defparameter *languages* '("ru" "en" "tr" "uk")
  "Поддерживаемые языки. Порядок влияет на переговоры по Accept-Language.")

(defparameter *language-labels*
  '(("ru" . "Русский")
    ("en" . "English")
    ("tr" . "Türkçe")
    ("uk" . "Українська"))
  "Нативные названия языков для переключателя.")

(defparameter *domain-languages*
  '((".ru" . "ru"))
  "Суффикс домена Host → язык по умолчанию. Например lisper.ru → ru.")

(defparameter *default-language* "en"
  "Язык по умолчанию, если домен не сопоставлен в *domain-languages*.")

(defvar *lang* *default-language*
  "Язык текущего запроса. Динамическая переменная, связывается в make-app.")

(defvar *path* "/"
  "Path текущего запроса (для ссылки «обратно» в /set-lang).")

(defvar *dicts* (make-hash-table :test #'equal))

(defun register-dict (lang alist)
  "Регистрирует словарь LANG (alist ключ→строка) в *dicts*."
  (let ((h (make-hash-table :test #'equal)))
    (dolist (pair alist)
      (setf (gethash (car pair) h) (cdr pair)))
    (setf (gethash lang *dicts*) h)))

(defun dict-value (lang key)
  (let ((d (gethash lang *dicts*)))
    (when d (gethash key d))))

(defun tr (key &optional (lang *lang*))
  "Перевод строки по ключу. Fallback: default-язык → '?key'."
  (let ((lang (if (member lang *languages* :test #'string=) lang *default-language*)))
    (or (dict-value lang key)
        (dict-value *default-language* key)
        (format nil "?~A" key))))

(defun tr-format (key &rest args)
  "Перевод + format с аргументами (для строк вида '~A ответов')."
  (apply #'format nil (tr key) args))

(defun language-label (lang)
  (cdr (assoc lang *language-labels* :test #'string=)))

;;; ------------------------------------------------------------
;;; Заголовки запроса
;;; ------------------------------------------------------------

(defun i18n-header (env name)
  "Значение заголовка запроса по нижнему регистру имени."
  (let ((headers (getf env :headers)))
    (when headers (gethash name headers))))

(defun cookie-value (env name)
  "Значение cookie по имени (case-insensitive) или NIL."
  (let ((cookies (i18n-header env "cookie")))
    (when cookies
      (loop for pair in (split-sequence:split-sequence #\; cookies)
            for kv = (split-sequence:split-sequence #\= (string-trim '(#\Space #\Tab) pair))
            when (and (first kv) (second kv)
                      (string-equal (string-trim '(#\Space #\Tab) (first kv)) name))
              return (string-trim '(#\Space #\Tab) (second kv))))))

;;; ------------------------------------------------------------
;;; Accept-Language
;;; ------------------------------------------------------------

(defun parse-lang-q (item)
  "Разбирает один элемент Accept-Language 'en-US;q=0.9' → (tag . q)."
  (let* ((parts (split-sequence:split-sequence #\; item))
         (tag (string-downcase (string-trim '(#\Space #\Tab) (first parts))))
         (q 1.0))
    (when (second parts)
      (let* ((params (split-sequence:split-sequence #\= (second parts)))
             (qv (ignore-errors (read-from-string (string-trim '(#\Space #\Tab) (second params))))))
        (when (and qv (numberp qv)) (setf q qv))))
    (cons tag q)))

(defun lang-matches-tag-p (lang tag)
  "LANG совпадает с тегом: точно или как префикс (en → en-US)."
  (or (string= lang tag)
      (and (> (length tag) (length lang))
           (string-equal lang (subseq tag 0 (length lang))))))

(defun best-language (header &optional (langs *languages*))
  "Лучший из *languages* по заголовку Accept-Language (по q, порядок списка)."
  (let ((best (first langs)) (best-q -1.0) (best-idx most-positive-fixnum))
    (dolist (item (split-sequence:split-sequence #\, header))
      (let* ((tag-q (parse-lang-q item))
             (tag (car tag-q)) (q (cdr tag-q)))
        (loop for l in langs
              for idx from 0
              when (and (lang-matches-tag-p l tag)
                        (or (> q best-q)
                            (and (= q best-q) (< idx best-idx))))
                do (setf best l best-q q best-idx idx))))
    best))

;;; ------------------------------------------------------------
;;; Домен → язык по умолчанию
;;; ------------------------------------------------------------

(defun domain-default-language (host)
  "Язык по умолчанию по суффиксу домена Host (например '.ru' → ru)."
  (when host
    (loop for (suffix . lang) in *domain-languages*
          when (and (>= (length host) (length suffix))
                    (string-equal suffix
                                  (subseq host (- (length host) (length suffix)))))
            return lang))
  *default-language*)

;;; ------------------------------------------------------------
;;; Детект языка запроса
;;; ------------------------------------------------------------

(defun normalize-lang (lang)
  "Приводит код языка к каноническому виду или NIL."
  (when lang
    (let ((code (string-downcase (string-trim '(#\Space #\Tab) lang))))
      (when (member code *languages* :test #'string=) code))))

(defun detect-language (env)
  "Язык запроса: cookie → Accept-Language → домен → default."
  (or (normalize-lang (cookie-value env "lang"))
      (let ((al (i18n-header env "accept-language")))
        (when al (best-language al)))
      (domain-default-language (i18n-header env "host"))
      *default-language*))

;;; ------------------------------------------------------------
;;; URL / JS-экранирование
;;; ------------------------------------------------------------

(defun url-encode (string)
  "Percent-encode для query-параметра next (путь)."
  (with-output-to-string (out)
    (loop for c across string
          do (if (or (alphanumericp c) (find c "-._~/"))
                 (write-char c out)
                 (format out "%~2,'0X" (char-code c))))))

(defun js-string (string)
  "Экранирует CL-строку в JS-строковый литерал."
  (with-output-to-string (out)
    (write-char #\" out)
    (loop for c across string
          do (case c
               (#\\ (write-string "\\\\" out))
               (#\" (write-string "\\\"" out))
               (#\Newline (write-string "\\n" out))
               (#\Return (write-string "\\r" out))
               (#\Tab (write-string "\\t" out))
               (t (write-char c out))))
    (write-char #\" out)))

;;; ------------------------------------------------------------
;;; Клиентский словарь (для site-бандла и игр)
;;; ------------------------------------------------------------

(defparameter *client-i18n-keys*
  '(:games-title
    :hint-lisp-invaders :hint-lambda-runner :hint-paren-matcher :hint-s-dungeon
    :game-load-error-title :game-no-bundle :md-empty)
  "Ключи, попадающие в window.LISPER_DICT на клиент.")

(defun client-i18n-key-name (key)
  (string-downcase (symbol-name key)))

(defun render-i18n-js (&optional (lang *lang*))
  "JS: window.LISPER_LANG + window.LISPER_DICT (клиентский словарь)."
  (with-output-to-string (out)
    (format out "window.LISPER_LANG=~A;" (js-string lang))
    (format out "window.LISPER_DICT={")
    (loop for key in *client-i18n-keys*
          for first = t then nil
          do (unless first (write-char #\, out))
             (format out "~A:~A"
                     (js-string (client-i18n-key-name key))
                     (js-string (tr key lang))))
    (format out "};")))

;;; ------------------------------------------------------------
;;; /set-lang: выбор языка + cookie
;;; ------------------------------------------------------------

(defun handle-set-lang (env)
  "Ставит cookie lang и редиректит обратно (next или Referer или '/')."
  (let* ((qs (parse-query-string env))
         (lang (when qs (gethash "lang" qs)))
         (next (when qs (gethash "next" qs))))
    (if (and lang (member lang *languages* :test #'string-equal))
        (let ((back (cond ((and next (plusp (length next))) next)
                          ((i18n-header env "referer") (i18n-header env "referer"))
                          (t "/"))))
          `(302 (:set-cookie ,(format nil "lang=~A; Path=/; Max-Age=31536000"
                                      (normalize-lang lang))
                             :location ,back)
                ("")))
        '(302 (:location "/") ("")))))

;;; ------------------------------------------------------------
;;; Переключатель языка в шапке
;;; ------------------------------------------------------------

(defun render-lang-switch ()
  "Выпадающий переключатель языка → /set-lang?lang=..&next=*path*.
   Текущий язык — заголовок кнопки, в меню подсвечен (клиентский JS в site.lisp
   открывает/закрывает меню по клику)."
  (cl-who:with-html-output-to-string (s)
    (:div :class "lang-dropdown"
      (:button :class "lang-dropdown-btn" :type "button"
               :aria-haspopup "true" :aria-expanded "false"
        (:span :class "lang-dropdown-label"
               (cl-who:str (or (language-label *lang*) (string-upcase *lang*))))
        (:span :class "lang-dropdown-caret" (cl-who:str "▾")))
      (:div :class "lang-dropdown-menu"
        (loop for lang in (sort (copy-list *languages*) #'string-lessp
                                :key (lambda (l) (or (language-label l) (string-upcase l))))
              do (cl-who:htm
                  (:a :class (when (string= lang *lang*) "active")
                      :href (format nil "/set-lang?lang=~A&next=~A"
                                    lang (url-encode *path*))
                      :title (or (language-label lang) (string-upcase lang))
                      (cl-who:str (or (language-label lang) (string-upcase lang))))))))))
