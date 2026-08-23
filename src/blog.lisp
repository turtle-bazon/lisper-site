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

(defun get-user-blog-posts (username &optional (offset 0) (limit 20))
  (postmodern:query
   "SELECT b.title, b.slug, TO_CHAR(b.created_at,'DD.MM.YYYY HH24:MI'),
           left(b.body, 400)
    FROM blog_posts b JOIN users u ON u.id = b.user_id
    WHERE u.username = $1
    ORDER BY b.created_at DESC OFFSET $2 LIMIT $3"
   username offset limit))

(defun get-all-blog-posts (&optional (offset 0) (limit 20))
  (postmodern:query
   "SELECT b.title, b.slug, TO_CHAR(b.created_at,'DD.MM.YYYY HH24:MI'),
           left(b.body, 400), u.username
    FROM blog_posts b JOIN users u ON u.id = b.user_id
    ORDER BY b.created_at DESC OFFSET $1 LIMIT $2"
   offset limit))

(defun get-blog-post-owner (post-id)
  (postmodern:query "SELECT user_id FROM blog_posts WHERE id = $1"
                    post-id :single))

(defun blog-excerpt (md-text)
  "Грубый текстовый отрывок markdown-источника для ленты."
  (let* ((cleaned (cl-ppcre:regex-replace-all
                   "[#*`>\\[\\]!]" (or md-text "") ""))
         (spaced (cl-ppcre:regex-replace-all "\\s{2,}" cleaned " ")))
    (if (> (length spaced) 300)
        (format nil "~a…" (subseq spaced 0 300))
        spaced)))

(defun valid-blog-title-p (s)
  (and (stringp s) (<= 3 (length s) 250)))

(defun valid-blog-body-p (s)
  (and (stringp s) (>= (length s) 1) (<= (length s) 100000)))
