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
                      u.username
               FROM topics t
               JOIN categories c ON t.category_id = c.id
               JOIN users u ON t.user_id = u.id
               WHERE t.id = $1"
              topic-id)))
    (when row
      (destructuring-bind (id cat-id user-id title created-at post-count cat-name cat-slug username)
          (first row)
        (list :id id :category-id cat-id :user-id user-id :title title
              :created-at created-at :post-count post-count
              :category-name cat-name :category-slug cat-slug
              :username username)))))

(defun get-posts (topic-id &optional (offset 0) (limit 50))
  (postmodern:query
   "SELECT p.id, p.body, TO_CHAR(p.created_at, 'DD.MM.YYYY HH24:MI'), u.username, u.role
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

;;; Audit logging

(defun log-audit (user-id action &optional target-type target-id details)
  "Log a moderation action."
  (postmodern:execute
   "INSERT INTO audit_log (user_id, action, target_type, target_id, details) VALUES ($1, $2, $3, $4, $5)"
   user-id action target-type target-id details))
