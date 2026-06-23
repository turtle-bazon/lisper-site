(in-package :lisper)

(defun env-method (env)
  (getf env :request-method))

(defun make-app ()
  (lambda (env)
    (handler-case
        (let* ((path (getf env :path-info))
               (user (ignore-errors (current-user env))))
          (cond
            ;; Static routes
            ((string= path "/")
             `(200 (:content-type "text/html; charset=utf-8")
                   (,(page-index))))
            ((string= path "/css")
             `(200 (:content-type "text/css; charset=utf-8")
                   (,(generate-css))))
            ((string= path "/js")
             `(200 (:content-type "application/javascript; charset=utf-8")
                   (,(generate-js))))

            ;; Auth routes
            ((and (string= path "/login") (eq (env-method env) :GET))
             `(200 (:content-type "text/html; charset=utf-8")
                   (,(forum-page-login user nil))))
            ((and (string= path "/login") (eq (env-method env) :POST))
             (handle-login env))
            ((and (string= path "/register") (eq (env-method env) :GET))
             `(200 (:content-type "text/html; charset=utf-8")
                   (,(forum-page-register user nil))))
            ((and (string= path "/register") (eq (env-method env) :POST))
             (handle-register env))
            ((and (string= path "/logout") (eq (env-method env) :GET))
             (handle-logout env))

            ;; Forum routes
            ((and (string= path "/forum") (eq (env-method env) :GET))
             `(200 (:content-type "text/html; charset=utf-8")
                   (,(forum-page-index user))))

            ;; Category page
            ((and (>= (length path) 7)
                  (string= (subseq path 0 7) "/forum/")
                  (eq (env-method env) :GET))
             (let ((slug (subseq path 7)))
               `(200 (:content-type "text/html; charset=utf-8")
                     (,(forum-page-category slug user)))))

            ;; New topic GET
            ((and (string= path "/new-topic") (eq (env-method env) :GET))
             (let ((cat (let ((qs (getf env :query-string)))
                          (when qs
                            (let ((pairs (split-sequence:split-sequence #\& qs)))
                              (loop for pair in pairs
                                    for (k v) = (split-sequence:split-sequence #\= pair)
                                    when (string= k "category")
                                      return v))))))
               `(200 (:content-type "text/html; charset=utf-8")
                     (,(forum-page-new-topic user cat)))))

            ;; New topic POST
            ((and (string= path "/new-topic") (eq (env-method env) :POST))
             (handle-new-topic env user))

            ;; Topic page
            ((and (>= (length path) 7)
                  (string= (subseq path 0 7) "/topic/")
                  (eq (env-method env) :GET))
             (let ((id (ignore-errors
                        (parse-integer (subseq path 7)))))
               (if id
                   `(200 (:content-type "text/html; charset=utf-8")
                         (,(forum-page-topic id user)))
                   '(404 (:content-type "text/html; charset=utf-8")
                     ("<h1>404</h1>")))))

            ;; New post POST
            ((and (string= path "/new-post") (eq (env-method env) :POST))
             (handle-new-post env user))

            ;; Delete post POST
            ((and (string= path "/delete-post") (eq (env-method env) :POST))
             (handle-delete-post env user))

            ;; 404
            (t
             '(404 (:content-type "text/html; charset=utf-8")
               ("<h1>404</h1>")))))
      (error (err)
        (list 500
              (list :content-type "text/html; charset=utf-8")
              (list (format nil "<h1>Ошибка</h1><p>~A</p>" err)))))))

(defun handle-login (env)
  (let* ((body (parse-post-body env))
         (email (gethash "email" body))
         (password (gethash "password" body))
         (token (when (and email password)
                  (authenticate-user email password))))
    (if token
        `(302 (:set-cookie ,(format nil "session=~A; Path=/; Max-Age=2592000" token)
                           :location "/forum")
              (""))
        (let ((user (ignore-errors (current-user env))))
          `(200 (:content-type "text/html; charset=utf-8")
                (,(forum-page-login user "Неверный email или пароль")))))))

(defun handle-register (env)
  (let* ((body (parse-post-body env))
         (username (gethash "username" body))
         (email (gethash "email" body))
         (password (gethash "password" body))
         (token (when (and username email password)
                  (register-user username email password))))
    (if token
        `(302 (:set-cookie ,(format nil "session=~A; Path=/; Max-Age=2592000" token)
                           :location "/forum")
              (""))
        (let ((user (ignore-errors (current-user env))))
          `(200 (:content-type "text/html; charset=utf-8")
                (,(forum-page-register user "Ошибка регистрации. Имя или email уже заняты.")))))))

(defun handle-logout (env)
  (let ((token (extract-session-token env)))
    (delete-session token)
    `(302 (:set-cookie "session=; Path=/; Max-Age=0"
                       :location "/")
          (""))))

(defun handle-new-topic (env user)
  (if (not user)
      '(302 (:location "/login") (""))
      (let* ((body (parse-post-body env))
             (category-slug (gethash "category" body))
             (title (gethash "title" body))
             (post-body (gethash "body" body))
             (cat (when category-slug (get-category-by-slug category-slug))))
        (if (and cat title post-body (plusp (length title)) (plusp (length post-body)))
            (let ((topic-id (create-topic (getf cat :id) (session-user-id user) title post-body)))
              `(302 (:location ,(format nil "/topic/~A" topic-id))
                    ("")))
            `(302 (:location "/new-topic") (""))))))

(defun handle-new-post (env user)
  (if (not user)
      '(302 (:location "/login") (""))
      (let* ((body (parse-post-body env))
             (topic-id (ignore-errors (parse-integer (gethash "topic-id" body))))
             (post-body (gethash "body" body)))
        (if (and topic-id post-body (plusp (length post-body)))
            (progn
              (create-post topic-id (session-user-id user) post-body)
              `(302 (:location ,(format nil "/topic/~A" topic-id))
                    ("")))
            `(302 (:location "/forum") (""))))))

(defun handle-delete-post (env user)
  (if (not user)
      '(302 (:location "/login") (""))
      (let* ((body (parse-post-body env))
             (post-id (ignore-errors (parse-integer (gethash "post-id" body))))
             (topic-id (ignore-errors (parse-integer (gethash "topic-id" body)))))
        (when (and post-id topic-id)
          (let ((row (first (postmodern:query
                             "SELECT user_id, topic_id FROM posts WHERE id = $1"
                             post-id))))
            (when row
              (let ((post-user-id (first row)))
                (when (or (user-moderator-p user)
                          (= (session-user-id user) post-user-id))
                  (delete-post post-id))))))
        `(302 (:location ,(format nil "/topic/~A" topic-id))
              ("")))))
