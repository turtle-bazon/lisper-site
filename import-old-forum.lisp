;;;; Импорт старого форума lisper.ru в БД сайта.
;;;;
;;;; Вход:  wayback/forum_parsed.json (см. wayback/parse_forum.py)
;;;; Выход: архивные категории «Архив: <имя>» + темы/посты от аккаунта
;;;;        oldlisper с полями old_thread_id/old_msg_id/old_reply_to/old_author.
;;;;
;;;; Схема: у topics НЕТ body — первый пост хранится как обычный пост;
;;;; reply_to в живом движке нет, старые id лежат в old_* колонках.
;;;;
;;;; Запуск:
;;;;   sbcl --non-interactive --load import-old-forum.lisp \
;;;;        [--conf /path/lisper.conf] [--json wayback/forum_parsed.json] [--force]
;;;;
;;;; Без --force отказывается работать, если в topics уже есть записи.

(ql:quickload :lisper :silent t)
(ql:quickload :jsown :silent t)
(ql:quickload :cl-ppcre :silent t)

(in-package :lisper)

(defparameter *args* (uiop:command-line-arguments))

(defun get-arg (flag &optional default)
  (let ((pos (position flag *args* :test #'string=)))
    (if (and pos (< (1+ pos) (length *args*)))
        (nth (1+ pos) *args*)
        default)))

(defparameter *conf-path* (get-arg "--conf" "lisper.conf"))
(defparameter *json-path* (get-arg "--json" "wayback/forum_parsed.json"))
(defparameter *force* (find "--force" *args* :test #'string=))

;;; --- конфиг из указанного файла
(setf lisper::*config*
      (with-open-file (s *conf-path*)
        (read s)))

(format t "~&Conf: ~a -> db=~a@~a:~a/~a~%"
        *conf-path*
        (config :db-user) (config :db-host) (config :db-port) (config :db-name))

(db-connect)

;;; --- защита: не импортировать в непустую базу без --force
(let ((n (postmodern:query "SELECT COUNT(*) FROM topics" :single)))
  (unless (or *force* (zerop n))
    (format t "~&ОТКАЗ: в topics уже ~a записей. Повторите с --force.~%" n)
    (uiop:quit 1)))

(run-pending-migrations)

;;; --- oldlisper: идемпотентный бутстрап
(defparameter *oldlisper-id*
  (let ((row (postmodern:query
              "SELECT id FROM users WHERE username = 'oldlisper'" :single)))
    (or row
        (postmodern:query
         "INSERT INTO users (username, email, password_hash, role)
          VALUES ('oldlisper', 'oldlisper@lisper.local', $1, 'user')
          RETURNING id"
         ;; пароль никому не известен — случайный, нигде не сохраняется
         (hash-password
          (ironclad:byte-array-to-hex-string (ironclad:random-data 32)))
         :single))))

(format t "~&oldlisper id=~a~%" *oldlisper-id*)

;;; --- санитизация старого HTML (wayback мог сохранить скрипты)
(defun sanitize-old-html (html)
  (when html
    (let ((s html))
      ;; скрипты/фреймы/объекты целиком
      (setf s (cl-ppcre:regex-replace-all "(?is)<script.*?</script>" s ""))
      (setf s (cl-ppcre:regex-replace-all "(?is)<iframe.*?</iframe>" s ""))
      (setf s (cl-ppcre:regex-replace-all "(?is)<object.*?</object>" s ""))
      ;; on*-обработчики и javascript:-ссылки
      (setf s (cl-ppcre:regex-replace-all
               "(?i)\\son[a-z]+\\s*=\\s*(\"[^\"]*\"|'[^']*'|[^\\s>]+)" s ""))
      (setf s (cl-ppcre:regex-replace-all "(?i)javascript:" s ""))
      ;; структурные теги старой вёрстки -> <br>: незакрытые <div> ломали
      ;; вёрстку страницы каскадом; текст по строкам сохраняем
      (setf s (cl-ppcre:regex-replace-all "(?i)<div[^>]*>" s ""))
      (setf s (cl-ppcre:regex-replace-all "(?i)</div>" s "<br>"))
      (setf s (cl-ppcre:regex-replace-all "(?i)<p[^>]*>" s ""))
      (setf s (cl-ppcre:regex-replace-all "(?i)</p>" s "<br>"))
      ;; сжать подряд идущие <br> и обрезать края
      (loop
        (let ((cleaned (cl-ppcre:regex-replace-all "(?i)(<br>\\s*){2,}" s "<br>")))
          (if (string= cleaned s) (return) (setf s cleaned))))
      (setf s (cl-ppcre:regex-replace-all "^(?i)(<br>\\s*)+" s ""))
      (setf s (cl-ppcre:regex-replace-all "(?i)(<br>\\s*)+$" s ""))
      s)))

(defun parse-date (s)
  "\"26.05.2013 09:36\" -> \"2013-05-26 09:36:00\" для PG."
  (when s
    (cl-ppcre:register-groups-bind (dd mm yyyy hh mi)
        ("(\\d{2})\\.(\\d{2})\\.\\s*(\\d{4})\\s+(\\d{1,2}):(\\d{2})" s)
      (format nil "~4,'0d-~2,'0d-~2,'0d ~2,'0d:~2,'0d:00"
              (parse-integer yyyy) (parse-integer mm) (parse-integer dd)
              (parse-integer hh) (parse-integer mi)))))

;;; jsown: опциональные ключи через val-safe
(defun jval (obj key &optional default)
  (multiple-value-bind (v present) (jsown:val-safe obj key)
    (if present v default)))

;;; --- категории «Архив: …» (идемпотентно)
(defun ensure-archive-category (slug name)
  (let* ((new-slug (format nil "archive-~A" slug))
         (title (format nil "Архив: ~A" (if (and name (plusp (length name)))
                                            name slug)))
         (row (first (postmodern:query
                      "SELECT id FROM categories WHERE slug = $1" new-slug))))
    (if row
        (first row)
        (postmodern:query
         "INSERT INTO categories (name, slug, description, sort_order, archived)
          VALUES ($1, $2, $3, 1000, TRUE) RETURNING id"
         title new-slug
         (format nil "Замороженные обсуждения старого форума lisper.ru (~A)"
                 title)
         :single))))

;;; --- основной проход
(let* ((data (jsown:parse (uiop:read-file-string *json-path*)))
       (threads (jsown:val data "threads"))
       (t-count 0) (p-count 0))
  (dolist (th threads)
    (let* ((cat-id (ensure-archive-category
                    (jval th "category_slug" "common-lisp")
                    (jval th "category_name")))
           ;; посты по дате; первый становится темой
           (posts (sort (copy-list (jsown:val th "posts"))
                        #'string< :key (lambda (p)
                                         (or (parse-date (jval p "date"))
                                             "9999")))))
      (when posts
        (let* ((first-post (first posts))
               (last-date (parse-date
                           (jval (car (last posts)) "date")))
               (created (or (parse-date (jval first-post "date"))
                            "2009-01-01 00:00:00"))
               (old-tid (jval th "id"))
               (topic-id (postmodern:query
                          "INSERT INTO topics
                             (category_id, user_id, title,
                              created_at, last_post_at, post_count,
                              old_thread_id, old_author)
                           VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
                           RETURNING id"
                          cat-id *oldlisper-id*
                          (let ((tt (jval th "title" "Без названия")))
                            (if (> (length tt) 250)
                                (subseq tt 0 250) tt))
                          created
                          (or last-date created)
                          (length posts)
                          (let ((v (when (and old-tid
                                              (every #'digit-char-p old-tid))
                                     (parse-integer old-tid))))
                            (or v :null))
                          (or (jval first-post "author") :null)
                          :single)))
          (incf t-count)
          (dolist (p posts)
            (let ((mid (jval p "msg_id")))
              (postmodern:query
               "INSERT INTO posts
                  (topic_id, user_id, body, created_at,
                   old_msg_id, old_author, old_reply_to)
                VALUES ($1,$2,$3,$4,$5,$6,$7)"
               topic-id *oldlisper-id*
               (sanitize-old-html (jval p "body_html" ""))
               (or (parse-date (jval p "date")) created)
               (if mid (parse-integer mid) :null)
               (or (jval p "author") :null)
               (let ((rt (jval p "reply_to")))
                 (if rt (parse-integer rt) :null)))
              (incf p-count))))))
    (format t "~&прогресс: тем=~a постов=~a~%" t-count p-count))

(format t "~&ИМПОРТ ЗАВЕРШЁН: тем=~a постов=~a~%" t-count p-count))

(postmodern:disconnect t)
(uiop:quit 0)
