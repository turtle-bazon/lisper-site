(in-package :lisper)

(defun get-categories ()
  (postmodern:query "SELECT id, name, slug, description, sort_order FROM categories ORDER BY sort_order"))

(defun get-category-by-slug (slug)
  (let ((row (first (postmodern:query "SELECT id, name, slug, description FROM categories WHERE slug = $1" slug))))
    (when row
      (destructuring-bind (id name slug-desc desc) row
        (list :id id :name name :slug slug-desc :description desc)))))

(defun get-topics (category-id &optional (offset 0) (limit 20))
  (postmodern:query
   "SELECT t.id, t.title, TO_CHAR(t.created_at, 'DD.MM.YYYY HH24:MI'), TO_CHAR(t.last_post_at, 'DD.MM.YYYY HH24:MI'), t.post_count,
           u.username
    FROM topics t
    JOIN users u ON t.user_id = u.id
    WHERE t.category_id = $1
    ORDER BY t.last_post_at DESC
    LIMIT $2 OFFSET $3"
   category-id limit offset))

(defun get-recent-topics (&optional (limit 10))
  (postmodern:query
   "SELECT t.id, t.title, TO_CHAR(t.created_at, 'DD.MM.YYYY HH24:MI'), t.post_count,
           c.name AS category_name, c.slug AS category_slug, u.username
    FROM topics t
    JOIN categories c ON t.category_id = c.id
    JOIN users u ON t.user_id = u.id
    ORDER BY t.last_post_at DESC
    LIMIT $1"
   limit))

(defun get-topic (topic-id)
  (let ((row (postmodern:query
              "SELECT t.id, t.category_id, t.user_id, t.title, TO_CHAR(t.created_at, 'DD.MM.YYYY HH24:MI'), t.post_count,
                      c.name AS category_name, c.slug AS category_slug,
                      u.username, c.archived, t.old_author
               FROM topics t
               JOIN categories c ON t.category_id = c.id
               JOIN users u ON t.user_id = u.id
               WHERE t.id = $1"
              topic-id)))
    (when row
      (destructuring-bind (id cat-id user-id title created-at post-count cat-name cat-slug username archived old-author)
          (first row)
        (list :id id :category-id cat-id :user-id user-id :title title
              :created-at created-at :post-count post-count
              :category-name cat-name :category-slug cat-slug
              :username username :archived archived :old-author old-author)))))

(defun get-posts (topic-id &optional (offset 0) (limit 50))
  (postmodern:query
   "SELECT p.id, p.body, TO_CHAR(p.created_at, 'DD.MM.YYYY HH24:MI'), u.username, u.role, p.old_author
    FROM posts p
    JOIN users u ON p.user_id = u.id
    WHERE p.topic_id = $1
    ORDER BY p.created_at ASC
    LIMIT $2 OFFSET $3"
   topic-id limit offset))

(defun create-topic (category-id user-id title body)
  (postmodern:execute
   "INSERT INTO topics (category_id, user_id, title) VALUES ($1, $2, $3)"
   category-id user-id title)
  (let ((topic-id (postmodern:query "SELECT currval('topics_id_seq')" :single)))
    (postmodern:execute
     "INSERT INTO posts (topic_id, user_id, body) VALUES ($1, $2, $3)"
     topic-id user-id body)
    (postmodern:execute
     "UPDATE topics SET post_count = 1 WHERE id = $1"
     topic-id)
    topic-id))

(defun create-post (topic-id user-id body)
  (postmodern:execute
   "INSERT INTO posts (topic_id, user_id, body) VALUES ($1, $2, $3)"
   topic-id user-id body)
  (postmodern:execute
   "UPDATE topics SET post_count = (SELECT COUNT(*) FROM posts WHERE topic_id = $1), last_post_at = NOW() WHERE id = $1"
   topic-id))

(defun category-archived-p (category-id)
  "Архивные разделы read-only."
  (let ((v (postmodern:query
            "SELECT archived FROM categories WHERE id = $1"
            category-id :single)))
    (and v (not (eq v :null)))))

(defun topic-category-archived-p (topic-id)
  (let ((row (postmodern:query
              "SELECT c.archived FROM topics t JOIN categories c ON c.id = t.category_id WHERE t.id = $1"
              topic-id :single)))
    (and row (not (eq row :null)))))

(defun topic-count (category-id)
  (postmodern:query
   "SELECT COUNT(*) FROM topics WHERE category_id = $1"
   category-id :single))

(defun post-count (topic-id)
  (postmodern:query
   "SELECT COUNT(*) FROM posts WHERE topic_id = $1"
   topic-id :single))

(defun delete-topic (topic-id)
  (postmodern:execute "DELETE FROM posts WHERE topic_id = $1" topic-id)
  (postmodern:execute "DELETE FROM topics WHERE id = $1" topic-id))

(defun delete-post (post-id)
  (let ((topic-id (postmodern:query
                   "SELECT topic_id FROM posts WHERE id = $1"
                   post-id :single)))
      (postmodern:execute "DELETE FROM posts WHERE id = $1" post-id)
      (when topic-id
        (postmodern:execute
         "UPDATE topics SET post_count = (SELECT COUNT(*) FROM posts WHERE topic_id = $1) WHERE id = $1"
         topic-id))))

(defun get-user-topic-count (user-id)
  (postmodern:query
   "SELECT COUNT(*) FROM topics WHERE user_id = $1"
   user-id :single))

(defun get-user-post-count (user-id)
  (postmodern:query
   "SELECT COUNT(*) FROM posts WHERE user_id = $1"
   user-id :single))

;;; ============ Поиск по форуму ============

(defun like-pattern (q)
  "Превращает пользовательский ввод в безопасный ILIKE-паттерн
   (экранирует %, _, \\ — иначе они работают как wildcards)."
  (with-output-to-string (out)
    (write-char #\% out)
    (loop for c across q
          do (case c
               (#\% (write-string "\\%" out))
               (#\_ (write-string "\\_" out))
               (#\\ (write-string "\\\\" out))
               (t (write-char c out))))
    (write-char #\% out)))

(defun search-forum-topics (query &optional (limit 20))
  "Темы форума, где query встречается в заголовке или в теле поста.
   Возвращает строки (id title category-name category-slug username post-count last-post-at)."
  (postmodern:query
   "SELECT t.id, t.title, c.name, c.slug, u.username, t.post_count,
           TO_CHAR(t.last_post_at, 'DD.MM.YYYY HH24:MI')
    FROM topics t
    JOIN categories c ON t.category_id = c.id
    JOIN users u ON t.user_id = u.id
    WHERE t.title ILIKE $1 ESCAPE '\\'
       OR EXISTS (SELECT 1 FROM posts p WHERE p.topic_id = t.id AND p.body ILIKE $1 ESCAPE '\\')
    ORDER BY t.last_post_at DESC
    LIMIT $2"
   (like-pattern query) limit))

;;; ============ Подписки на темы ============

(defun subscribe-topic (topic-id user-id)
  (postmodern:execute
   "INSERT INTO topic_subscriptions (topic_id, user_id, last_read_at)
    VALUES ($1, $2, NOW())
    ON CONFLICT (topic_id, user_id) DO NOTHING"
   topic-id user-id))

(defun unsubscribe-topic (topic-id user-id)
  (postmodern:execute
   "DELETE FROM topic_subscriptions WHERE topic_id = $1 AND user_id = $2"
   topic-id user-id))

(defun topic-subscribed-p (topic-id user-id)
  (postmodern:query
   "SELECT 1 FROM topic_subscriptions WHERE topic_id = $1 AND user_id = $2"
   topic-id user-id :single))

(defun mark-topic-read (topic-id user-id)
  "Подписчик прочитал тему — сбрасываем счётчик новых ответов."
  (postmodern:execute
   "UPDATE topic_subscriptions SET last_read_at = NOW()
    WHERE topic_id = $1 AND user_id = $2"
   topic-id user-id))

(defun topic-unread-count (topic-id user-id)
  "Кол-во новых ответов с момента последнего прочтения (0, если не подписан)."
  (let ((n (postmodern:query
            "SELECT COUNT(*)
             FROM posts p
             JOIN topic_subscriptions s ON s.topic_id = p.topic_id AND s.user_id = $2
             WHERE p.topic_id = $1 AND p.created_at > s.last_read_at"
            topic-id user-id :single)))
    (if (eq n :null) 0 n)))

(defun get-user-subscriptions (user-id)
  "Подписки пользователя: (topic-id title category-name category-slug
   username last-post-at unread)."
  (postmodern:query
   "SELECT t.id, t.title, c.name, c.slug, u.username,
           TO_CHAR(t.last_post_at, 'DD.MM.YYYY HH24:MI'),
           (SELECT COUNT(*)
              FROM posts p
              WHERE p.topic_id = t.id
                AND p.created_at > s.last_read_at)
    FROM topic_subscriptions s
    JOIN topics t ON t.id = s.topic_id
    JOIN categories c ON t.category_id = c.id
    JOIN users u ON t.user_id = u.id
    WHERE s.user_id = $1
    ORDER BY t.last_post_at DESC"
   user-id))

;;; Settings functions

(defun get-setting (key)
  "Get a setting value from the database."
  (postmodern:query "SELECT value FROM settings WHERE key = $1" key :single))

(defun set-setting (key value)
  "Set a setting value in the database."
  (postmodern:execute "INSERT INTO settings (key, value) VALUES ($1, $2) ON CONFLICT (key) DO UPDATE SET value = $2"
                      key value))

(defun forum-closed-p ()
  "Check if the forum is closed for posting."
  (let ((val (get-setting "forum_closed")))
    (and val (string= val "true"))))

(defun toggle-forum ()
  "Toggle the forum open/closed state. Returns new state."
  (if (forum-closed-p)
      (progn (set-setting "forum_closed" "false") nil)
      (progn (set-setting "forum_closed" "true") t)))

(defun registration-closed-p ()
  "Check if new registrations are temporarily closed."
  (let ((val (get-setting "registration_closed")))
    (and val (string= val "true"))))

(defun toggle-registration ()
  "Toggle registration open/closed state. Returns new state."
  (if (registration-closed-p)
      (progn (set-setting "registration_closed" "false") nil)
      (progn (set-setting "registration_closed" "true") t)))

;;; Управление разделами (категориями) форума — только админ

(defun valid-slug-p (s)
  (and (stringp s)
       (>= (length s) 2) (<= (length s) 50)
       (every (lambda (c) (or (char= c #\-) (alphanumericp c))) s)))

(defun category-topic-count (category-id)
  (postmodern:query "SELECT COUNT(*) FROM topics WHERE category_id = $1"
                    category-id :single))

(defun create-category (name slug description sort-order)
  (handler-case
      (progn
        (postmodern:execute
         "INSERT INTO categories (name, slug, description, sort_order) VALUES ($1, $2, $3, $4)"
         name slug description sort-order)
        t)
    (cl-postgres:database-error () nil)))

(defun update-category (id name description sort-order)
  "slug не меняется — на него могут ссылаться внешние ссылки."
  (postmodern:execute
   "UPDATE categories SET name = $2, description = $3, sort_order = $4 WHERE id = $1"
   id name description sort-order))

(defun delete-category (id)
  "Удаляет раздел только если в нём нет тем. Возвращает T/NIL."
  (handler-case
      (if (zerop (category-topic-count id))
          (progn
            (postmodern:execute "DELETE FROM categories WHERE id = $1" id)
            t)
          nil)
    (cl-postgres:database-error () nil)))

;;; Audit logging

(defun log-audit (user-id action &optional target-type target-id details)
  "Log a moderation action. NIL -> SQL NULL (:null), иначе postmodern
превращает NIL в строку \"false\" и INTEGER-колонка падает (22P02)."
  (postmodern:execute
   "INSERT INTO audit_log (user_id, action, target_type, target_id, details) VALUES ($1, $2, $3, $4, $5)"
   (if user-id user-id :null)
   action
   (if target-type target-type :null)
   (if target-id target-id :null)
   (if details details :null)))
