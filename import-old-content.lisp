;;;; Импорт старого контента lisper.ru (статьи, wiki, посты блога 2009-2015)
;;;; в блог сайта от аккаунта oldlisper. Тела хранятся как HTML (is_html=TRUE).
;;;;
;;;; Вход:  wayback/content_parsed.json (см. wayback/parse_content.py)
;;;; Запуск:
;;;;   sbcl --non-interactive --load import-old-content.lisp \
;;;;        [--conf /path/lisper.conf] [--json wayback/content_parsed.json] [--force]

(ql:quickload :lisper :silent t)
(ql:quickload :jsown :silent t)
(ql:quickload :cl-ppcre :silent t)

(in-package :lisper)

(defparameter *args* (uiop:command-line-arguments))

(defun jval (obj key &optional default)
  (multiple-value-bind (v present) (jsown:val-safe obj key)
    (if present v default)))

(defun get-arg (flag &optional default)
  (let ((pos (position flag *args* :test #'string=)))
    (if (and pos (< (1+ pos) (length *args*)))
        (nth (1+ pos) *args*)
        default)))

(defparameter *conf-path* (get-arg "--conf" "lisper.conf"))
(defparameter *json-path* (get-arg "--json" "wayback/content_parsed.json"))
(defparameter *force* (find "--force" *args* :test #'string=))

(setf lisper::*config*
      (with-open-file (s *conf-path*) (read s)))

(format t "~&Conf: ~a -> db=~a@~a:~a/~a~%"
        *conf-path*
        (config :db-user) (config :db-host) (config :db-port) (config :db-name))
(db-connect)

;;; защита: только в пустой блог или с --force
(let ((n (postmodern:query "SELECT COUNT(*) FROM blog_posts" :single)))
  (unless (or *force* (zerop n))
    (format t "~&ОТКАЗ: в blog_posts уже ~a записей. Повторите с --force.~%" n)
    (uiop:quit 1)))

(run-pending-migrations)

;;; oldlisper — идемпотентно
(defparameter *oldlisper-id*
  (let ((row (postmodern:query
              "SELECT id FROM users WHERE username = 'oldlisper'" :single)))
    (or row
        (postmodern:query
         "INSERT INTO users (username, email, password_hash, role)
          VALUES ('oldlisper', 'oldlisper@lisper.local', $1, 'user')
          RETURNING id"
         (hash-password
          (ironclad:byte-array-to-hex-string (ironclad:random-data 32)))
         :single))))
(format t "~&oldlisper id=~a~%" *oldlisper-id*)

;;; --force: чистый реимпорт — удаляем старые посты oldlisper
(when *force*
  (postmodern:execute
   "DELETE FROM blog_posts WHERE user_id = $1" *oldlisper-id*)
  (format t "~&--force: удалены старые посты oldlisper~%"))

;;; --- санитизация (как в forum-импорте)
(defun sanitize-old-html (html)
  (when html
    (let ((s html))
      (setf s (cl-ppcre:regex-replace-all "(?is)<script.*?</script>" s ""))
      (setf s (cl-ppcre:regex-replace-all "(?is)<iframe.*?</iframe>" s ""))
      (setf s (cl-ppcre:regex-replace-all "(?is)<object.*?</object>" s ""))
      (setf s (cl-ppcre:regex-replace-all
               "(?i)\\son[a-z]+\\s*=\\s*(\"[^\"]*\"|'[^']*'|[^\\s>]+)" s ""))
      (setf s (cl-ppcre:regex-replace-all "(?i)javascript:" s ""))
      s)))

;;; --- уникальный слаг для oldlisper (генерируем из заголовка,
;;;     как в blog.lisp, чтобы совпадал со стилем новых постов)
(defun unique-content-slug (title)
  (let ((base (make-blog-slug title))
        (candidate nil) (n 0))
    (loop
      do (setf candidate (if (zerop n) base (format nil "~a-~d" base n)))
         (incf n)
         (let ((exists (postmodern:query
                        "SELECT 1 FROM blog_posts WHERE user_id = $1 AND slug = $2"
                        *oldlisper-id* candidate :single)))
           (unless exists (return candidate))))))

;;; --- основной проход
(let* ((data (jsown:parse (uiop:read-file-string *json-path*)))
       (posts (jsown:val data "posts"))
       (ok 0) (err 0))
    (dolist (p posts)
      (let* ((title (let ((tt (jval p "title" "Без названия")))
                      (if (> (length tt) 250) (subseq tt 0 250) tt)))
             (slug (unique-content-slug title))
             (date (jval p "date" nil))
             (body (sanitize-old-html (jval p "body_html" "")))
             ;; автор: реальное имя или сентинл "old-wiki";
             ;; без авторства — SQL NULL (:null!), т.к. postmodern превращает
             ;; Lisp NIL в SQL false (см. AGENTS.md «подводные камни»)
             (author (let ((a (jval p "author" nil)))
                       (if (and a (plusp (length a))) a :null))))
       (handler-case
           (progn
             (postmodern:query
              "INSERT INTO blog_posts (user_id, title, slug, body, created_at, updated_at, is_html, old_author)
               VALUES ($1,$2,$3,$4,$5,$5,TRUE,$6)"
              *oldlisper-id* title slug body
              (if (and date (>= (length date) 10)) date "2010-01-01 00:00:00")
              author)
             (incf ok))
         (error (e)
           (incf err)
           (format t "~&FAIL ~a: ~a~%" slug e)))))
  (format t "~&ИМПОРТ ЗАВЕРШЁН: ok=~a err=~a~%" ok err))

(db-disconnect)(uiop:quit 0)
