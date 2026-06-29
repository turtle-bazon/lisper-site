(in-package :lisper)

(defun env-method (env)
  (getf env :request-method))

(defun security-headers ()
  "Return security headers as a plist."
  (list :x-content-type-options "nosniff"
        :x-frame-options "DENY"
        :x-xss-protection "0"
        :referrer-policy "strict-origin-when-cross-origin"
         :content-security-policy "default-src 'self'; script-src 'self' 'unsafe-eval' https://cdnjs.cloudflare.com; style-src 'self' 'unsafe-inline' https://cdnjs.cloudflare.com; img-src 'self' data:; font-src 'self' https://cdnjs.cloudflare.com; connect-src 'self'; frame-ancestors 'none'"))

(defun add-security-headers (response)
  "Add security headers to a Clack response."
  (destructuring-bind (status headers body) response
    (list status (append headers (security-headers)) body)))

(defun parse-query-string (env)
  (let ((qs (getf env :query-string)))
    (when qs
      (let ((pairs (split-sequence:split-sequence #\& qs))
            (result (make-hash-table :test #'equal)))
        (loop for pair in pairs
              for parts = (split-sequence:split-sequence #\= pair)
              for key = (url-decode (first parts))
              for val = (url-decode (or (second parts) ""))
              do (setf (gethash key result) val))
        result))))

(defun make-app ()
  (lambda (env)
    (handler-case
        (add-security-headers
         (let* ((path (getf env :path-info))
                (user (ignore-errors (current-user env))))
           (cond
            ;; Static routes
            ((string= path "/")
                   `(200 (:content-type "text/html; charset=utf-8")
                          (,(page-index user))))
            ((string= path "/css")
             `(200 (:content-type "text/css; charset=utf-8")
                   (,(generate-css))))
             ((string= path "/js")
              `(200 (:content-type "application/javascript; charset=utf-8")
                    (,(generate-js))))
             ((string= path "/jscl.js")
               `(200 (:content-type "application/javascript; charset=utf-8")
                     (,*jscl-js*)))

             ;; Game source download
             ((and (>= (length path) 13)
                   (string= (subseq path 0 13) "/game-source/"))
              (let* ((name (subseq path 13))
                     (src (get-game-source name)))
                (if src
                    `(200 (:content-type "text/plain; charset=utf-8")
                          (,(cdr src)))
                    '(404 (:content-type "text/plain; charset=utf-8")
                      ("Game not found")))))

             ;; Tool source download
             ((and (>= (length path) 13)
                   (string= (subseq path 0 13) "/tool-source/"))
              (let* ((name (subseq path 13))
                     (src (get-tool-source name)))
                (if src
                    `(200 (:content-type "text/plain; charset=utf-8")
                          (,(cdr src)))
                    '(404 (:content-type "text/plain; charset=utf-8")
                      ("Tool not found")))))


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
             (let ((cat (let ((qs (parse-query-string env)))
                          (when qs (gethash "category" qs)))))
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

            ;; Delete topic POST
            ((and (string= path "/delete-topic") (eq (env-method env) :POST))
             (handle-delete-topic env user))

            ;; User profile
            ((and (>= (length path) 6)
                  (string= (subseq path 0 6) "/user/")
                  (eq (env-method env) :GET))
             (let ((name (subseq path 6)))
               `(200 (:content-type "text/html; charset=utf-8")
                     (,(forum-page-user name user)))))

            ;; Admin: user list
            ((and (string= path "/admin/users") (eq (env-method env) :GET))
             (if (and user (user-admin-p user))
                 `(200 (:content-type "text/html; charset=utf-8")
                       (,(forum-page-admin-users user)))
                 '(403 (:content-type "text/html; charset=utf-8")
                   ("<h1>403 Доступ запрещён</h1>"))))

            ;; Admin: mute user POST
            ((and (string= path "/admin/mute") (eq (env-method env) :POST))
             (handle-mute-user env user))

            ;; Admin: unmute user POST
            ((and (string= path "/admin/unmute") (eq (env-method env) :POST))
             (handle-unmute-user env user))

            ;; Admin: set role POST
            ((and (string= path "/admin/set-role") (eq (env-method env) :POST))
             (handle-set-role env user))

            ;; Admin: toggle forum
            ((and (string= path "/admin/toggle-forum") (eq (env-method env) :POST))
             (handle-toggle-forum env user))

            ;; 404
            (t
             '(404 (:content-type "text/html; charset=utf-8")
               ("<h1>404</h1>"))))))
      (error (err)
        (add-security-headers
         (list 500
               (list :content-type "text/html; charset=utf-8")
               (list (format nil "<h1>Ошибка</h1><p>~A</p>" err))))))))

(defun handle-login (env)
  (let ((user (ignore-errors (current-user env))))
    `(200 (:content-type "text/html; charset=utf-8")
          (,(forum-page-login user "Вход временно отключён. Скоро будет доступен вход через VK ID, Yandex ID и Госуслуги.")))))

(defun handle-register (env)
  (let ((user (ignore-errors (current-user env))))
    `(200 (:content-type "text/html; charset=utf-8")
          (,(forum-page-register user "Регистрация временно отключена. Скоро будет доступен вход через VK ID, Yandex ID и Госуслуги.")))))

(defun handle-logout (env)
  (let ((token (extract-session-token env)))
    (delete-session token)
    `(302 (:set-cookie "session=; Path=/; Max-Age=0"
                       :location "/")
          (""))))

(defun handle-new-topic (env user)
  (if (not user)
      '(302 (:location "/login") (""))
      (if (and (forum-closed-p) (not (user-admin-p user)))
          `(302 (:location "/forum?closed=1")
                (""))
          (if (is-muted-p (session-user-id user))
              `(302 (:location ,(format nil "/topic/0?muted=1"))
                    (""))
              (let* ((body (parse-post-body env))
                     (category-slug (gethash "category" body))
                     (title (gethash "title" body))
                     (post-body (gethash "body" body))
                     (cat (when category-slug (get-category-by-slug category-slug))))
                (if (and cat title post-body (plusp (length title)) (plusp (length post-body)))
                    (let ((topic-id (create-topic (getf cat :id) (session-user-id user) title post-body)))
                      `(302 (:location ,(format nil "/topic/~A" topic-id))
                            ("")))
                    `(302 (:location "/new-topic") (""))))))))

(defun handle-new-post (env user)
  (if (not user)
      '(302 (:location "/login") (""))
      (if (and (forum-closed-p) (not (user-admin-p user)))
          (let ((topic-id (ignore-errors (parse-integer (gethash "topic-id" (parse-post-body env))))))
            `(302 (:location ,(format nil "/topic/~A?closed=1" (or topic-id 0)))
                  ("")))
          (if (is-muted-p (session-user-id user))
              (let ((topic-id (ignore-errors (parse-integer (gethash "topic-id" (parse-post-body env))))))
                `(302 (:location ,(format nil "/topic/~A" (or topic-id 0)))
                      ("")))
              (let* ((body (parse-post-body env))
                     (topic-id (ignore-errors (parse-integer (gethash "topic-id" body))))
                     (post-body (gethash "body" body)))
                (if (and topic-id post-body (plusp (length post-body)))
                    (progn
                      (create-post topic-id (session-user-id user) post-body)
                      `(302 (:location ,(format nil "/topic/~A" topic-id))
                            ("")))
                     `(302 (:location "/forum") (""))))))))

(defun handle-delete-post (env user)
  (if (not user)
      '(302 (:location "/login") (""))
      (let* ((body (parse-post-body env))
             (post-id (ignore-errors (parse-integer (gethash "post-id" body))))
             (topic-id (ignore-errors (parse-integer (gethash "topic-id" body)))))
        (when (and post-id topic-id)
          (let ((row (first (postmodern:query
                             "SELECT user_id FROM posts WHERE id = $1"
                             post-id))))
            (when row
              (let ((post-user-id (first row)))
                (when (or (user-moderator-p user)
                          (= (session-user-id user) post-user-id))
                  (delete-post post-id)
                  (log-audit (session-user-id user) "delete-post" "post" post-id))))))
        `(302 (:location ,(format nil "/topic/~A" topic-id))
              ("")))))

(defun handle-delete-topic (env user)
  (if (not user)
      '(302 (:location "/login") (""))
      (if (not (user-moderator-p user))
          '(403 (:content-type "text/html; charset=utf-8")
            ("<h1>403 Доступ запрещён</h1>"))
          (let* ((body (parse-post-body env))
                 (topic-id (ignore-errors (parse-integer (gethash "topic-id" body))))
                 (cat-slug (gethash "category-slug" body)))
            (when topic-id
              (delete-topic topic-id)
              (log-audit (session-user-id user) "delete-topic" "topic" topic-id))
            `(302 (:location ,(if cat-slug
                                  (format nil "/forum/~A" cat-slug)
                                  "/forum"))
                  (""))))))

(defun handle-mute-user (env user)
  (if (not (and user (user-moderator-p user)))
      '(403 (:content-type "text/html; charset=utf-8")
        ("<h1>403</h1>"))
      (let* ((body (parse-post-body env))
             (target-id (ignore-errors (parse-integer (gethash "user-id" body))))
             (duration (gethash "duration" body)))
        (when (and target-id duration)
          (mute-user target-id duration)
          (log-audit (session-user-id user) "mute-user" "user" target-id duration))
        (let ((back (gethash "back" body)))
          `(302 (:location ,(or back "/admin/users"))
                (""))))))

(defun handle-unmute-user (env user)
  (if (not (and user (user-moderator-p user)))
      '(403 (:content-type "text/html; charset=utf-8")
        ("<h1>403</h1>"))
      (let* ((body (parse-post-body env))
             (target-id (ignore-errors (parse-integer (gethash "user-id" body)))))
        (when target-id
          (unmute-user target-id)
          (log-audit (session-user-id user) "unmute-user" "user" target-id))
        (let ((back (gethash "back" body)))
          `(302 (:location ,(or back "/admin/users"))
                (""))))))

(defun handle-set-role (env user)
  (if (not (and user (user-admin-p user)))
      '(403 (:content-type "text/html; charset=utf-8")
        ("<h1>403</h1>"))
      (let* ((body (parse-post-body env))
             (target-id (ignore-errors (parse-integer (gethash "user-id" body))))
             (role (gethash "role" body)))
        (when (and target-id role
                   (member role '("user" "moderator" "admin") :test #'string=))
          (set-user-role target-id role)
          (log-audit (session-user-id user) "set-role" "user" target-id role))
        (let ((back (gethash "back" body)))
          `(302 (:location ,(or back "/admin/users"))
                (""))))))

(defun handle-toggle-forum (env user)
  (if (not (and user (user-admin-p user)))
      '(403 (:content-type "text/html; charset=utf-8")
        ("<h1>403</h1>"))
      (progn
        (toggle-forum)
        (log-audit (session-user-id user) "toggle-forum" "setting" nil (if (forum-closed-p) "closed" "opened"))
        `(302 (:location "/admin/users")
              ("")))))
