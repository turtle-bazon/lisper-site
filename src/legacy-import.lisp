;;; Импорт старого контента lisper.ru (форум + блог/статьи/wiki)
;;; в БД сайта от аккаунта oldlisper. Вызывается через CLI
;;; (`lisper import forum|content`, см. cli.lisp).
;;;
;;; Семантика перенесена 1:1 из скриптов import-old-forum.lisp /
;;; import-old-content.lisp (удалены после рефакторинга):
;;;   * форум: без --force отказ при непустом topics; категории «Архив:
;;;     …» идемпотентны по slug; повторный запуск ДУБЛИРУЕТ темы;
;;;   * контент: --force удаляет посты oldlisper перед вставкой
;;;     (чистый реимпорт, чужие посты не трогает);
;;;   * у форумных и контентных тел РАЗНЫЕ санитайзеры (см. ниже).

(in-package :lisper)

;;; --- общие помощники -------------------------------------------------

(defun import-load-conf (path)
  "Читает .conf файл, печатает сводку и подключается к БД."
  (setf lisper::*config*
        (with-open-file (s path) (read s)))
  (format t "~&Conf: ~a -> db=~a@~a:~a/~a~%"
          path
          (config :db-user) (config :db-host) (config :db-port) (config :db-name))
  (db-connect))

(defun ensure-oldlisper ()
  "Аккаунт oldlisper — идемпотентно; пароль случайный и нигде не хранится."
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

(defun jval (obj key &optional default)
  (multiple-value-bind (v present) (jsown:val-safe obj key)
    (if present v default)))

;;; --- форум -------------------------------------------------------------

(defun parse-date (s)
  "\"26.05.2013 09:36\" -> \"2013-05-26 09:36:00\" для PG."
  (when s
    (cl-ppcre:register-groups-bind (dd mm yyyy hh mi)
        ("(\\d{2})\\.(\\d{2})\\.\\s*(\\d{4})\\s+(\\d{1,2}):(\\d{2})" s)
      (format nil "~4,'0d-~2,'0d-~2,'0d ~2,'0d:~2,'0d:00"
              (parse-integer yyyy) (parse-integer mm) (parse-integer dd)
              (parse-integer hh) (parse-integer mi)))))

(defun sanitize-forum-html (html)
  "Санитизация старых форумных постов: структурные теги старой вёрстки
   превращаются в <br> (незакрытые <div> ломали вёрстку каскадом),
   текст по строкам сохраняется."
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
      ;; структурные теги старой вёрстки -> <br>
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

(defun ensure-archive-category (slug name)
  "Категория «Архив: …» — идемпотентно по slug."
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

(defun import-forum-main (conf-path json-path force)
  "Импорт старого форума. Возвращает (VALUES тем постов).
   Без FORCE отказывает, если topics непусты."
  (import-load-conf conf-path)
  (let ((n (postmodern:query "SELECT COUNT(*) FROM topics" :single)))
    (unless (or force (zerop n))
      (error "ОТКАЗ: в topics уже ~a записей. Повторите с --force.~%" n)))
  (run-pending-migrations)
  (let* ((oldlisper-id (ensure-oldlisper))
         (data (jsown:parse (uiop:read-file-string json-path)))
         (threads (jsown:val data "threads"))
         (t-count 0) (p-count 0))
    (format t "~&oldlisper id=~a~%" oldlisper-id)
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
                            cat-id oldlisper-id
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
                 topic-id oldlisper-id
                 (sanitize-forum-html (jval p "body_html" ""))
                 (or (parse-date (jval p "date")) created)
                 (if mid (parse-integer mid) :null)
                 (or (jval p "author") :null)
                 (let ((rt (jval p "reply_to")))
                   (if rt (parse-integer rt) :null)))
                (incf p-count)))))
        (format t "~&прогресс: тем=~a постов=~a~%" t-count p-count)))
    (db-disconnect)
    (format t "~&ИМПОРТ ФОРУМА ЗАВЕРШЁН: тем=~a постов=~a~%" t-count p-count)
    (values t-count p-count)))

;;; --- блог / статьи / wiki ----------------------------------------------

(defun sanitize-legacy-html (html)
  "Санитизация статей/wiki/блога: сохраняем структуру (рендер .legacy-html),
   вырезаем только скрипты/фреймы/on*-обработчики/javascript:-ссылки."
  (when html
    (let ((s html))
      (setf s (cl-ppcre:regex-replace-all "(?is)<script.*?</script>" s ""))
      (setf s (cl-ppcre:regex-replace-all "(?is)<iframe.*?</iframe>" s ""))
      (setf s (cl-ppcre:regex-replace-all "(?is)<object.*?</object>" s ""))
      (setf s (cl-ppcre:regex-replace-all
               "(?i)\\son[a-z]+\\s*=\\s*(\"[^\"]*\"|'[^']*'|[^\\s>]+)" s ""))
      (setf s (cl-ppcre:regex-replace-all "(?i)javascript:" s ""))
      s)))

(defun unique-content-slug (oldlisper-id title)
  "Уникальный слаг для oldlisper — генерируется из заголовка, как в blog.lisp."
  (let ((base (make-blog-slug title))
        (candidate nil) (n 0))
    (loop
      do (setf candidate (if (zerop n) base (format nil "~a-~d" base n)))
         (incf n)
         (let ((exists (postmodern:query
                        "SELECT 1 FROM blog_posts WHERE user_id = $1 AND slug = $2"
                        oldlisper-id candidate :single)))
           (unless exists (return candidate))))))

(defun import-content-main (conf-path json-path force)
  "Импорт блога/статей/wiki. Возвращает (VALUES ok err).
   FORCE удаляет существующие посты oldlisper перед вставкой."
  (import-load-conf conf-path)
  (let ((n (postmodern:query "SELECT COUNT(*) FROM blog_posts" :single)))
    (unless (or force (zerop n))
      (error "ОТКАЗ: в blog_posts уже ~a записей. Повторите с --force.~%" n)))
  (run-pending-migrations)
  (let* ((oldlisper-id (ensure-oldlisper)))
    (format t "~&oldlisper id=~a~%" oldlisper-id)
    (when force
      (postmodern:execute
       "DELETE FROM blog_posts WHERE user_id = $1" oldlisper-id)
      (format t "~&--force: удалены старые посты oldlisper~%"))
    (let* ((data (jsown:parse (uiop:read-file-string json-path)))
           (posts (jsown:val data "posts"))
           (ok 0) (err 0))
      (dolist (p posts)
        (let* ((title (let ((tt (jval p "title" "Без названия")))
                        (if (> (length tt) 250) (subseq tt 0 250) tt)))
               (slug (unique-content-slug oldlisper-id title))
               (date (jval p "date" nil))
               (body (sanitize-legacy-html (jval p "body_html" "")))
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
                 oldlisper-id title slug body
                 (if (and date (>= (length date) 10)) date "2010-01-01 00:00:00")
                 author)
                (incf ok))
            (error (e)
              (incf err)
              (format t "~&FAIL ~a: ~a~%" slug e))))))
      (db-disconnect)
      (format t "~&ИМПОРТ КОНТЕНТА ЗАВЕРШЁН: ok=~a err=~a~%" ok err)
      (values ok err)))
