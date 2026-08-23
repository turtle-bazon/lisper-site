(in-package :lisper)

;;; Блоги пользователей: CRUD + выборки.
;;; Тело поста хранится как markdown (как посты форума),
;;; рендерится клиентским парсером (.md-content).

(defparameter *translit-table*
  ;; кириллица -> латиница для слагов
  "a b v g d e zh z i y k l m n o p r s t u f h c ch sh shch '' y '' e yu ya"
  )

(defun transliterate (s)
  (let ((pairs '(("а" . "a") ("б" . "b") ("в" . "v") ("г" . "g") ("д" . "d")
                 ("е" . "e") ("ё" . "e") ("ж" . "zh") ("з" . "z") ("и" . "i")
                 ("й" . "y") ("к" . "k") ("л" . "l") ("м" . "m") ("н" . "n")
                 ("о" . "o") ("п" . "p") ("р" . "r") ("с" . "s") ("т" . "t")
                 ("у" . "u") ("ф" . "f") ("х" . "h") ("ц" . "c") ("ч" . "ch")
                 ("ш" . "sh") ("щ" . "sch") ("ъ" . "") ("ы" . "y") ("ь" . "")
                 ("э" . "e") ("ю" . "yu") ("я" . "ya"))))
    (with-output-to-string (out)
      (loop for ch across (string-downcase s)
            do (let* ((c (string ch))
                      (hit (assoc c pairs :test #'string=)))
                 (cond (hit (write-string (cdr hit) out))
                       ((alphanumericp ch) (write-char ch out))
                       (t (write-char #\- out))))))))

(defun make-blog-slug (title)
  "Заголовок -> слаг [a-z0-9-], 3-140, без лишних дефисов."
  (let* ((raw (transliterate title))
         (collapsed (cl-ppcre:regex-replace-all "-{2,}" raw "-"))
         (trimmed (string-trim "-" collapsed)))
    (if (> (length trimmed) 140)
        (string-trim "-" (subseq trimmed 0 140))
        trimmed)))

(defun unique-blog-slug (user-id title)
  "Слаг с суффиксом -2/-3… если у автора уже есть такой."
  (let ((base (make-blog-slug title))
        (candidate nil) (n 0))
    (loop
      do (setf candidate (if (zerop n) base (format nil "~a-~d" base n)))
         (incf n)
         (let ((exists (postmodern:query
                        "SELECT 1 FROM blog_posts WHERE user_id = $1 AND slug = $2"
                        user-id candidate :single)))
           (unless exists (return candidate))))
    candidate))

(defun create-blog-post (user-id title body)
  (let ((slug (unique-blog-slug user-id title)))
    (postmodern:query
     "INSERT INTO blog_posts (user_id, title, slug, body) VALUES ($1,$2,$3,$4)
      RETURNING id"
     user-id title slug body :single)))

(defun update-blog-post (post-id title body)
  (postmodern:execute
   "UPDATE blog_posts SET title = $2, body = $3, updated_at = NOW() WHERE id = $1"
   post-id title body))

(defun delete-blog-post (post-id)
  (postmodern:execute "DELETE FROM blog_posts WHERE id = $1" post-id))

(defun get-blog-post-by-slug (username slug)
  (let ((row (first (postmodern:query
                     "SELECT b.id, b.user_id, b.title, b.slug, b.body,
                             TO_CHAR(b.created_at,'DD.MM.YYYY HH24:MI'),
                             TO_CHAR(b.updated_at,'DD.MM.YYYY HH24:MI'),
                             u.username
                      FROM blog_posts b JOIN users u ON u.id = b.user_id
                      WHERE u.username = $1 AND b.slug = $2"
                     username slug))))
    (when row
      (destructuring-bind (id user-id title pslug body created updated uname) row
        (list :id id :user-id user-id :title title :slug pslug :body body
              :created-at created :updated-at updated :username uname)))))

(defun get-user-blog-posts (username &key (offset 0) (limit 20) year month)
  ;; username приходит из роутов сайта; числа — целые после parse-integer
  (let ((ym (if (and year month)
                (format nil " AND EXTRACT(YEAR FROM b.created_at)::int=~d
                             AND EXTRACT(MONTH FROM b.created_at)::int=~d"
                        year month)
                ""))
        (lim (format nil " ORDER BY b.created_at DESC OFFSET ~d LIMIT ~d"
                     (max 0 offset) (max 0 limit))))
    (postmodern:query
     (concatenate 'string
       "SELECT b.title, b.slug, TO_CHAR(b.created_at,'DD.MM.YYYY HH24:MI'), left(b.body,2000),
               EXTRACT(YEAR FROM b.created_at)::int AS y,
               EXTRACT(MONTH FROM b.created_at)::int AS m
        FROM blog_posts b JOIN users u ON u.id=b.user_id
        WHERE u.username = '" username "'" ym lim))))

(defun get-all-blog-posts (&key (offset 0) (limit 20) year month)
  (let ((ym (if (and year month)
                (format nil " AND EXTRACT(YEAR FROM b.created_at)::int=~d
                             AND EXTRACT(MONTH FROM b.created_at)::int=~d"
                        year month)
                ""))
        (lim (format nil " ORDER BY b.created_at DESC OFFSET ~d LIMIT ~d"
                     (max 0 offset) (max 0 limit))))
    (postmodern:query
     (concatenate 'string
       "SELECT b.title, b.slug, TO_CHAR(b.created_at,'DD.MM.YYYY HH24:MI'), left(b.body,2000), u.username
        FROM blog_posts b JOIN users u ON u.id=b.user_id WHERE true"
       ym lim))))


(defun get-blog-date-tree (&optional username)
  "(год месяц кол-во) для дерева дат; опционально одного автора."
  (if username
      (postmodern:query
        "SELECT EXTRACT(YEAR FROM b.created_at)::int, EXTRACT(MONTH FROM b.created_at)::int, COUNT(*)
         FROM blog_posts b JOIN users u ON u.id=b.user_id
         WHERE u.username = $1 GROUP BY 1,2 ORDER BY 1 DESC, 2 DESC" username)
       (postmodern:query
        "SELECT EXTRACT(YEAR FROM created_at)::int, EXTRACT(MONTH FROM created_at)::int, COUNT(*)
         FROM blog_posts GROUP BY 1,2 ORDER BY 1 DESC, 2 DESC")))

(defun strip-html (s)
  "Удаляет HTML-теги и сворачивает whitespace — для текстовых тизеров карточек."
  (when s
    (let ((t1 (cl-ppcre:regex-replace-all "<[^>]*>" s " ")))
      (cl-ppcre:regex-replace-all "\\s+" t1 " "))))

(defun blog-card-excerpt (body)
  "Чистый текстовый тизер карточки: без тегов, ≤280 символов.
   Лечит баг вложенных <div> (legacy-HTML тела резались посреди тега)."
  (let* ((raw (if (and body (> (length body) 0))
                  (subseq body 0 (min (length body) 2000)) ""))
         (txt (strip-html raw)))
    (string-trim " "
                 (if (> (length txt) 280)
                     (concatenate 'string (subseq txt 0 280) "…")
                     txt))))

(defun blog-card-truncated-p (body)
  "Тизер обрезан? (чтобы показывать «Читать далее» только при необходимости)."
  (let ((raw (if (and body (> (length body) 0))
                 (subseq body 0 (min (length body) 2000)) "")))
    (> (length (strip-html raw)) 280)))

(defun valid-blog-title-p (s)
  (and (stringp s) (<= 3 (length s) 250)))

(defun valid-blog-body-p (s)
  (and (stringp s) (>= (length s) 1) (<= (length s) 100000)))




