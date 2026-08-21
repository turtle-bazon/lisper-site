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
        (let* ((path (getf env :path-info))
               (*lang* (detect-language env))
               (*path* path)
               (user (ignore-errors (current-user env))))
          (add-security-headers
           (maybe-track-analytics
            env
            path
            (cond
            ;; i18n: переключение языка (cookie) + клиентский словарь
            ((string= path "/set-lang")
             (handle-set-lang env))
            ((string= path "/i18n.js")
             `(200 (:content-type "application/javascript; charset=utf-8")
                   (,(render-i18n-js *lang*))))
            ;; Static routes
            ((string= path "/")
                   `(200 (:content-type "text/html; charset=utf-8")
                          (,(page-index user))))
             ((string= path "/css")
              `(200 (:content-type "text/css; charset=utf-8")
                    (,(generate-css))))
             ((string= path "/jscl.js")
               `(200 (:content-type "application/javascript; charset=utf-8"
                      :cache-control "public, max-age=31536000, immutable")
                     (,*jscl-js*)))

             ;; Compiled JSCL bundle (versioned URL: /jscl-bundle/<name>?v=<hash>)
             ((and (>= (length path) 13)
                   (string= (subseq path 0 13) "/jscl-bundle/"))
              (let* ((name (subseq path 13))
                     (src (get-jscl-bundle name)))
                (if src
                    `(200 (:content-type "application/javascript; charset=utf-8"
                           :cache-control "public, max-age=31536000, immutable")
                          (,src))
                    '(404 (:content-type "text/plain; charset=utf-8")
                      ("Bundle not found")))))

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
                    (,(forum-page-register user nil (registration-closed-p)))))
             ((and (string= path "/register") (eq (env-method env) :POST))
              (handle-register env))
            ((and (string= path "/logout") (eq (env-method env) :GET))
             (handle-logout env))
            ((and (string= path "/rules") (eq (env-method env) :GET))
             `(200 (:content-type "text/html; charset=utf-8")
                   (,(forum-page-rules user))))

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
             (let* ((qs (parse-query-string env))
                    (cat (when qs (gethash "category" qs)))
                    (throttled (and qs (gethash "throttled" qs))))
               `(200 (:content-type "text/html; charset=utf-8")
                     (,(forum-page-new-topic user cat throttled)))))

            ;; New topic POST
            ((and (string= path "/new-topic") (eq (env-method env) :POST))
             (handle-new-topic env user))

            ;; Topic page
            ((and (>= (length path) 7)
                  (string= (subseq path 0 7) "/topic/")
                  (eq (env-method env) :GET))
             (let* ((id (ignore-errors
                         (parse-integer (subseq path 7))))
                    (qs (parse-query-string env))
                    (throttled (and qs (gethash "throttled" qs))))
               (if id
                   `(200 (:content-type "text/html; charset=utf-8")
                         (,(forum-page-topic id user throttled)))
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
                  `(403 (:content-type "text/html; charset=utf-8")
                    (,(format nil "<h1>~A</h1>" (tr :403))))))

;; Admin: analytics dashboard
            ((and (string= path "/admin/analytics") (eq (env-method env) :GET))
             (if (and user (user-admin-p user))
                 (let ((bot-filter (analytics-parse-tab (getf env :query-string)))
                       (own-hosts (list (request-header env "host"))))
                   `(200 (:content-type "text/html; charset=utf-8")
                         (,(forum-page-analytics user bot-filter own-hosts "/admin/analytics"))))
                 `(403 (:content-type "text/html; charset=utf-8")
                   (,(format nil "<h1>~A</h1>" (tr :403))))))

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

            ;; Admin: toggle registration
            ((and (string= path "/admin/toggle-registration") (eq (env-method env) :POST))
             (handle-toggle-registration env user))

            ;; Admin: категории форума
            ((and (string= path "/admin/categories") (eq (env-method env) :GET))
             (if (and user (user-admin-p user))
                 `(200 (:content-type "text/html; charset=utf-8")
                       (,(forum-page-admin-categories
                          user (gethash "error" (or (parse-query-string env)
                                                    (make-hash-table :test #'equal))))))
                 `(403 (:content-type "text/html; charset=utf-8")
                   (,(format nil "<h1>~A</h1>" (tr :403))))))

            ((and (string= path "/admin/category-create") (eq (env-method env) :POST))
             (handle-category-create env user))

            ((and (string= path "/admin/category-update") (eq (env-method env) :POST))
             (handle-category-update env user))

            ((and (string= path "/admin/category-delete") (eq (env-method env) :POST))
             (handle-category-delete env user))

            ;; Hidden analytics URL (no login): /analytics/<admin-secret>
            ;; Для владельца, если сессия недоступна; /admin/* по-прежнему
            ;; только по admin-сессии.
            ((and (eq (env-method env) :GET)
                  (config :admin-secret)
                  (string= path (format nil "/analytics/~A" (config :admin-secret))))
             (let ((bot-filter (analytics-parse-tab (getf env :query-string)))
                   (tab-base (format nil "/analytics/~A" (config :admin-secret)))
                   (own-hosts (list (request-header env "host"))))
               `(200 (:content-type "text/html; charset=utf-8")
                     (,(forum-page-analytics user bot-filter own-hosts tab-base)))))

;; 404
             (t
              '(404 (:content-type "text/html; charset=utf-8")
                ("<h1>404</h1>")))))))
      (error (err)
        (add-security-headers
         (list 500
               (list :content-type "text/html; charset=utf-8")
               (list (format nil "<h1>~A</h1><p>~A</p>" (tr :500-error) err))))))))

(defun auth-session-cookie (token)
  (format nil "session=~A; Path=/; Max-Age=2592000; HttpOnly; SameSite=Lax" token))

(defun handle-login (env)
  (rate-maybe-cleanup)
  (let* ((body (parse-post-body env))
         (ip (or (request-ip env) "unknown"))
         (email (gethash "email" body))
         (password (gethash "password" body))
         (fts (gethash "fts" body)))
    (labels ((page (msg)
               (let ((user (ignore-errors (current-user env))))
                 `(200 (:content-type "text/html; charset=utf-8")
                       (,(forum-page-login user msg))))))
      (cond
        ;; Brute-force защита: 10 попыток в 15 минут на IP
        ((not (rate-allowed-p (list :login ip) 10 900))
         (page (tr :auth-rate-limited)))
        ;; Слепые POST без подписанной формы — бот
        ((not (verify-form-token fts))
         (page (tr :auth-too-fast)))
        (t
         (let ((token (when (and email password)
                        (ignore-errors (authenticate-user email password)))))
           (if token
               `(302 (:set-cookie ,(auth-session-cookie token)
                                  :location "/forum")
                     (""))
               (page (tr :login-failed)))))))))

(defun handle-register (env)
  (rate-maybe-cleanup)
  (let* ((body (parse-post-body env))
         (ip (or (request-ip env) "unknown"))
         (ua (request-user-agent env))
         (username (gethash "username" body))
         (email (gethash "email" body))
         (password (gethash "password" body))
         (website (gethash "website" body))
         (fts (gethash "fts" body))
         (captcha (gethash "captcha" body))
         (captcha-token (gethash "captcha-token" body)))
    (labels ((page (msg)
               (let ((user (ignore-errors (current-user env))))
                 `(200 (:content-type "text/html; charset=utf-8")
                       (,(forum-page-register user msg))))))
      (cond
        ;; Регистрация закрыта админом
        ((registration-closed-p)
         (page (tr :registration-closed)))
        ;; Не более 5 регистраций в час с одного IP
        ((not (rate-allowed-p (list :register ip) 5 3600))
         (page (tr :auth-rate-limited)))
        ;; Известные bot-UA (curl/wget/...) — generic-ошибка, не раскрываем причину
        ((bot-user-agent-p ua)
         (page (tr :register-failed)))
        ;; Honeypot заполнен — бот; отдаём generic-ошибку, не раскрывая причину
        ((and website (plusp (length (string-trim " " website))))
         (page (tr :register-failed)))
        ;; Форма отправлена раньше 2 секунд после рендера или подпись битая
        ((not (verify-form-token fts))
         (page (tr :auth-too-fast)))
        ;; Анимированная noise-CAPTCHA
        ((not (verify-captcha captcha-token captcha))
         (page (tr :captcha-failed)))
        ;; Proof-of-work: клиент обязан был потратить CPU
        ((not (verify-pow (gethash "pow-challenge" body)
                          (gethash "pow-nonce" body)))
         (page (tr :pow-failed)))
        ;; Согласие с правилами и обработкой персональных данных
        ((not (gethash "agree" body))
         (page (tr :register-must-agree)))
        ((not (valid-username-p username))
         (page (tr :invalid-username)))
        ((not (valid-email-p email))
         (page (tr :invalid-email)))
        ((not (valid-password-p password))
         (page (tr :weak-password)))
        (t
         (let ((token (register-user username email password)))
           (if token
               `(302 (:set-cookie ,(auth-session-cookie token)
                                  :location "/forum")
                     (""))
               (page (tr :register-failed)))))))))

(defun handle-logout (env)
  (let ((token (extract-session-token env)))
    (delete-session token)
    `(302 (:set-cookie "session=; Path=/; Max-Age=0"
                       :location "/")
          (""))))

(defun user-last-content-age (user-id)
  "Секунды с последнего поста/топика пользователя; NIL, если ещё ничего не писал."
  (postmodern:query
   "SELECT COALESCE(EXTRACT(EPOCH FROM (NOW() - MAX(created_at))), 99999)::int
    FROM (SELECT created_at FROM posts WHERE user_id = $1
          UNION ALL SELECT created_at FROM topics WHERE user_id = $1) t"
   user-id :single))

(defun posting-throttled-p (user-id &optional (min-interval 30))
  "Антиспам: не чаще одного поста/топика в MIN-INTERVAL секунд."
  (let ((age (user-last-content-age user-id)))
    (and age (< age min-interval))))

(defun handle-new-topic (env user)
  (if (not user)
      '(302 (:location "/login") (""))
      (let* ((body (parse-post-body env))
             (category-slug (gethash "category" body))
             (title (gethash "title" body))
             (post-body (gethash "body" body))
             (cat (when category-slug (get-category-by-slug category-slug))))
        (cond
          ((and (forum-closed-p) (not (user-admin-p user)))
           `(302 (:location "/forum?closed=1")
                 ("")))
          ((is-muted-p (session-user-id user))
           `(302 (:location ,(format nil "/topic/0?muted=1"))
                 ("")))
          ;; Антиспам: не чаще поста в 30 секунд
          ((posting-throttled-p (session-user-id user))
           `(302 (:location "/new-topic?throttled=1")
                 ("")))
          ((and cat title post-body (plusp (length title)) (plusp (length post-body)))
           (let ((topic-id (create-topic (getf cat :id) (session-user-id user) title post-body)))
             `(302 (:location ,(format nil "/topic/~A" topic-id))
                   (""))))
          (t
           `(302 (:location "/new-topic") ("")))))))

(defun handle-new-post (env user)
  (if (not user)
      '(302 (:location "/login") (""))
      (let* ((body (parse-post-body env))
             (topic-id (ignore-errors (parse-integer (gethash "topic-id" body))))
             (post-body (gethash "body" body)))
        (cond
          ((and (forum-closed-p) (not (user-admin-p user)))
           `(302 (:location ,(format nil "/topic/~A?closed=1" (or topic-id 0)))
                 ("")))
          ((is-muted-p (session-user-id user))
           `(302 (:location ,(format nil "/topic/~A" (or topic-id 0)))
                 ("")))
          ;; Антиспам: не чаще поста в 30 секунд
          ((posting-throttled-p (session-user-id user))
           `(302 (:location ,(format nil "/topic/~A?throttled=1" (or topic-id 0)))
                 ("")))
          ((and topic-id post-body (plusp (length post-body)))
           (create-post topic-id (session-user-id user) post-body)
           `(302 (:location ,(format nil "/topic/~A" topic-id))
                 ("")))
          (t
           `(302 (:location "/forum") ("")))))))

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
          `(403 (:content-type "text/html; charset=utf-8")
            (,(format nil "<h1>~A</h1>" (tr :403))))
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

(defun handle-toggle-registration (env user)
  (if (not (and user (user-admin-p user)))
      '(403 (:content-type "text/html; charset=utf-8")
        ("<h1>403</h1>"))
      (progn
        (toggle-registration)
        (log-audit (session-user-id user) "toggle-registration" "setting" nil (if (registration-closed-p) "closed" "opened"))
        `(302 (:location "/admin/users")
              ("")))))

(defun admin-cat-redirect (&optional error-msg)
  `(302 (:location ,(if error-msg
                        (format nil "/admin/categories?error=~A"
                                (url-encode error-msg))
                        "/admin/categories"))
        ("")))

(defun handle-category-create (env user)
  (if (not (and user (user-admin-p user)))
      '(403 (:content-type "text/html; charset=utf-8")
        ("<h1>403</h1>"))
      (let* ((body (parse-post-body env))
             (name (string-trim " " (or (gethash "name" body) "")))
             (slug (string-trim " " (or (gethash "slug" body) "")))
             (desc (or (gethash "description" body) ""))
             (sort (ignore-errors (parse-integer (gethash "sort" body)))))
        (cond
          ((or (not sort) (< (length name) 1) (not (valid-slug-p slug)))
           (admin-cat-redirect (tr :cat-invalid)))
          ((not (create-category name slug desc sort))
           ;; дубликат slug или другая ошибка БД
           (admin-cat-redirect (tr :cat-slug-taken)))
          (t
           (log-audit (session-user-id user) "category-create" "category" nil
                      (format nil "slug=~A name=~A" slug name))
           (admin-cat-redirect))))))

(defun handle-category-update (env user)
  (if (not (and user (user-admin-p user)))
      '(403 (:content-type "text/html; charset=utf-8")
        ("<h1>403</h1>"))
      (let* ((body (parse-post-body env))
             (id (ignore-errors (parse-integer (gethash "id" body))))
             (name (string-trim " " (or (gethash "name" body) "")))
             (desc (or (gethash "description" body) ""))
             (sort (ignore-errors (parse-integer (gethash "sort" body)))))
        (when (and id sort (plusp (length name)))
          (update-category id name desc sort)
          (log-audit (session-user-id user) "category-update" "category" id))
        (admin-cat-redirect))))

(defun handle-category-delete (env user)
  (if (not (and user (user-admin-p user)))
      '(403 (:content-type "text/html; charset=utf-8")
        ("<h1>403</h1>"))
      (let* ((body (parse-post-body env))
             (id (ignore-errors (parse-integer (gethash "id" body)))))
        (if (and id (delete-category id))
            (progn
              (log-audit (session-user-id user) "category-delete" "category" id)
              (admin-cat-redirect))
            ;; в разделе есть темы — удалить нельзя
            (admin-cat-redirect (tr :cat-not-empty))))))

