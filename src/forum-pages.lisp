(in-package :lisper)

(defun url-decode (string)
  (let ((bytes (make-array (length string) :element-type '(unsigned-byte 8) :fill-pointer 0))
        (i 0)
        (len (length string)))
    (loop while (< i len) do
      (let ((ch (char string i)))
        (cond
          ((char= ch #\+)
           (vector-push-extend (char-code #\Space) bytes)
           (incf i))
          ((and (char= ch #\%) (< (+ i 2) len))
           (let ((hex (subseq string (+ i 1) (+ i 3))))
             (vector-push-extend (parse-integer hex :radix 16) bytes)
             (incf i 3)))
          (t
           (vector-push-extend (char-code ch) bytes)
           (incf i)))))
    (flexi-streams:octets-to-string bytes :external-format :utf-8)))

(defun parse-post-body (env)
  (let ((content-type (getf env :content-type))
        (body-stream (getf env :raw-body)))
    (when (and content-type body-stream)
      (let ((content (let ((buf (make-array 4096 :element-type '(unsigned-byte 8) :fill-pointer 0)))
                       (loop for byte = (read-byte body-stream nil nil)
                             while byte
                             do (vector-push-extend byte buf))
                                              (flexi-streams:octets-to-string buf :external-format :utf-8))))
        (let ((pairs (split-sequence:split-sequence #\& content)))
          (let ((result (make-hash-table :test #'equal)))
            (loop for pair in pairs
                  for parts = (split-sequence:split-sequence #\= pair)
                  for key = (url-decode (first parts))
                  for val = (url-decode (or (second parts) ""))
                  do (setf (gethash key result) val))
            result))))))

(defun get-form-value (env key)
  (let ((body (getf env :parsed-body)))
    (when body (gethash key body))))

(defun forum-render-head (title)
  (cl-who:with-html-output-to-string (s)
    (:meta :charset "utf-8")
    (:meta :name "viewport" :content "width=device-width, initial-scale=1")
    (:title (cl-who:str title))
    (:link :rel "icon" :type "image/svg+xml" :href *favicon-data-uri*)
    (:style (cl-who:str (generate-css)))
    (:script :defer t :src "/i18n.js")
    (:script :defer t :src (jscl-url))
    (:script :defer t :src (jscl-bundle-url "site"))))

(defun forum-render-header (user)
  (cl-who:with-html-output-to-string (s)
    (:div :class "site-header"
     (:div :class "header-left"
      (:a :href "/" :class "header-logo"
       (cl-who:str *logo-svg*)))
     (:nav :class "header-nav"
      (:a :href "/" (:span :class "nav-icon" (cl-who:str "<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8'/><path d='M3 10a2 2 0 0 1 .709-1.528l7-6a2 2 0 0 1 2.582 0l7 6A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z'/></svg>")) (cl-who:str (tr :nav-home)))
      (:a :href "tg://resolve?domain=commonlisp_ru" (:span :class "nav-icon" (cl-who:str "<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 240 240'><circle cx='120' cy='120' r='120' fill='#229ED9'/><path d='M81.229,128.772l14.237,39.406s1.78,3.687,3.686,3.687,30.255-29.492,30.255-29.492l31.525-60.89L81.737,118.6Z' fill='#c8daea'/><path d='M100.106,138.878l-2.733,29.046s-1.144,8.9,7.754,0,17.415-15.763,17.415-15.763' fill='#a9c6d8'/><path d='M81.486,130.178,52.2,120.636s-3.5-1.42-2.373-4.64c.232-.664.7-1.229,2.1-2.2,6.489-4.523,120.106-45.36,120.106-45.36s3.208-1.081,5.1-.362a2.766,2.766,0,0,1,1.885,2.055,9.357,9.357,0,0,1,.254,2.585c-.009.752-.1,1.449-.169,2.542-.692,11.165-21.4,94.493-21.4,94.493s-1.239,4.876-5.678,5.043A8.13,8.13,0,0,1,146.1,172.5c-8.711-7.493-38.819-27.727-45.472-32.177a1.27,1.27,0,0,1-.546-.9c-.093-.469.417-1.05.417-1.05s52.426-46.6,53.821-51.492c.108-.379-.3-.566-.848-.4-3.482,1.281-63.844,39.4-70.506,43.607A3.21,3.21,0,0,1,81.486,130.178Z' fill='#fff'/></svg>")) (cl-who:str (tr :nav-telegram)))
      (:a :href "/forum" (:span :class "nav-icon" (cl-who:str "<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M2.992 16.342a2 2 0 0 1 .094 1.167l-1.065 3.29a1 1 0 0 0 1.236 1.168l3.413-.998a2 2 0 0 1 1.099.092 10 10 0 1 0-4.777-4.719'/></svg>")) (cl-who:str (tr :nav-forum))))
     (:div :class "header-right"
      (cl-who:str (render-lang-switch))
      (if user
          (cl-who:htm
           (when (user-admin-p user)
             (cl-who:htm
              (:a :class "header-admin" :href "/admin/users" (cl-who:str (tr :admin)))
              (:a :class "header-admin" :href "/admin/analytics" (cl-who:str (tr :analytics)))))
           (:a :class "header-user" :href (format nil "/user/~A" (session-username user))
               (cl-who:str (session-username user)))
           (:a :class "header-logout" :href "/logout" (cl-who:str (tr :logout))))
          (cl-who:htm
           (:a :class "header-login" :href "/login" (cl-who:str (tr :login)))
           (:a :class "header-register" :href "/register" (cl-who:str (tr :register)))))))))

(defun forum-render-editor (name &optional (placeholder (tr :editor-placeholder)))
  "Render a rich markdown editor with toolbar and preview."
  (cl-who:with-html-output-to-string (s)
    (:div :class "md-editor"
     (:div :class "md-toolbar"
      (:button :type "button" :class "md-btn" :data-action "bold" :title (tr :md-bold) "B")
      (:button :type "button" :class "md-btn" :data-action "italic" :title (tr :md-italic) "I")
      (:button :type "button" :class "md-btn" :data-action "strike" :title (tr :md-strike) "S")
      (:span :class "md-sep")
      (:button :type "button" :class "md-btn" :data-action "h1" :title (tr :md-h1) "H1")
      (:button :type "button" :class "md-btn" :data-action "h2" :title (tr :md-h2) "H2")
      (:button :type "button" :class "md-btn" :data-action "h3" :title (tr :md-h3) "H3")
      (:span :class "md-sep")
      (:button :type "button" :class "md-btn" :data-action "ul" :title (tr :md-ul) "• —")
      (:button :type "button" :class "md-btn" :data-action "ol" :title (tr :md-ol) "1.")
      (:button :type "button" :class "md-btn" :data-action "quote" :title (tr :md-quote) "« »")
      (:span :class "md-sep")
      (:button :type "button" :class "md-btn" :data-action "code" :title (tr :md-code) "&lt;/&gt;")
      (:button :type "button" :class "md-btn" :data-action "link" :title (tr :md-link) "🔗")
      (:button :type "button" :class "md-btn" :data-action "image" :title (tr :md-image) "🖼")
      (:span :class "md-sep")
      (:button :type "button" :class "md-btn md-preview-btn" :data-action "preview" :title (tr :md-preview) "👁"))
     (:textarea :name name :class "md-textarea" :placeholder placeholder
                :required "required")
     (:div :class "md-preview" :style "display:none"))))

(defun forum-page-index (user)
  (let ((categories (get-categories))
        (recent (get-recent-topics 10)))
    (cl-who:with-html-output-to-string (s nil :prologue "<!DOCTYPE html>")
      (cl-who:htm
       (:html :lang *lang*
        (:head (cl-who:str (forum-render-head (tr :forum-title))))
        (:body
         (:div :class "container"
          (:header (cl-who:str (forum-render-header user)))
          (:div :class "section"
           (:h2 (cl-who:str (tr :forum)))
           (when user
             (cl-who:htm
              (:div :class "forum-actions"
                    (:a :class "try-button" :href "/new-topic" (cl-who:str (tr :new-topic-btn))))))
           (:div :class "forum-categories"
                 (loop for (id name slug desc) in categories
                       do (cl-who:htm
                           (:div :class "forum-cat-card"
                                 (:a :class "forum-cat-link"
                                     :href (format nil "/forum/~A" slug)
                                     (:h3 (cl-who:str name))
                                     (:p (cl-who:str desc))
                                     (:span :class "forum-cat-count"
                                            (cl-who:str (tr-format :topics-count (topic-count id)))))))))
           (:div :class "section"
                 (:h2 (cl-who:str (tr :recent-topics)))
                 (if recent
                     (cl-who:htm
                      (:div :class "topic-list"
                            (loop for (id title created-at post-count cat-name cat-slug username)
                                  in recent
                                  do (cl-who:htm
                                      (:div :class "topic-row"
                                            (:a :class "topic-link"
                                                :href (format nil "/topic/~A" id)
                                                (:span :class "topic-title" (cl-who:str title))
                                                (:span :class "topic-meta"
                                                       (cl-who:str
                                                        (tr-format :topic-meta post-count cat-name)))))))))
                     (cl-who:htm
                      (:p :class "empty-state" (cl-who:str (tr :empty-topics)))))))
           (:footer (:p (:a :href "https://github.com/turtle-bazon/lisper-site" "lisper")
                        " &copy; 2026 | GPL-3.0")))))))))

(defun forum-page-category (category user)
  (let ((cat (get-category-by-slug category)))
    (if cat
        (let ((topics (get-topics (getf cat :id))))
          (cl-who:with-html-output-to-string (s nil :prologue "<!DOCTYPE html>")
            (cl-who:htm
             (:html :lang *lang*
              (:head (cl-who:str (forum-render-head (format nil "~A — ~A" (getf cat :name) (tr :forum)))))
              (:body
               (:div :class "container"
                (:header (cl-who:str (forum-render-header user)))
                (:div :class "section"
                 (:a :class "back-link" :href "/forum" (cl-who:str (tr :back-to-forum)))
                 (:h2 (cl-who:str (getf cat :name)))
                 (:p :class "section-sub" (cl-who:str (getf cat :description)))
                 (when user
                   (cl-who:htm
                    (:a :class "try-button" :href
                        (format nil "/new-topic?category=~A" (getf cat :slug))
                        (cl-who:str (tr :new-topic-btn)))))
                 (if topics
                     (cl-who:htm
                      (:div :class "topic-list"
                            (loop for (id title created-at last-post-at post-count username)
                                  in topics
                                  do (cl-who:htm
                                      (:div :class "topic-row"
                                            (:a :class "topic-link"
                                                :href (format nil "/topic/~A" id)
                                                (:span :class "topic-title" (cl-who:str title))
                                                (:span :class "topic-meta"
                                                       (cl-who:str
                                                        (tr-format :topic-meta-2 post-count username last-post-at)))))))))
                     (cl-who:htm
                      (:p :class "empty-state" (cl-who:str (tr :empty-category)))))))
               (:footer (:p (:a :href "https://github.com/turtle-bazon/lisper-site" "lisper")
                             " &copy; 2026 | GPL-3.0")))))))
        (forum-page-not-found user))))

(defun forum-page-topic (topic-id user &optional throttled)
  (let ((topic (get-topic topic-id)))
    (if topic
        (let ((posts (get-posts topic-id)))
          (cl-who:with-html-output-to-string (s nil :prologue "<!DOCTYPE html>")
            (cl-who:htm
             (:html :lang *lang*
              (:head (cl-who:str (forum-render-head (getf topic :title))))
              (:body
               (:div :class "container"
                (:header (cl-who:str (forum-render-header user)))
                (:div :class "section"
                 (:a :class "back-link"
                     :href (format nil "/forum/~A" (getf topic :category-slug))
                     (cl-who:str (format nil "← ~A" (getf topic :category-name))))
                 (:h2 (cl-who:str (getf topic :title)))
                 (:div :class "topic-info"
                       (:span (cl-who:str (tr :topic-author)))
                       (:a :class "post-author" :href (format nil "/user/~A" (getf topic :username))
                           (cl-who:str (getf topic :username)))
                       (:span (cl-who:str (format nil " · ~A" (getf topic :created-at)))))
                 (when (and user (user-moderator-p user))
                   (cl-who:htm
                    (:div :class "topic-moderation"
                          (:form :method "POST" :action "/delete-topic" :style "display:inline"
                                 :onsubmit (format nil "return confirm('~A')" (tr :confirm-delete-topic))
                                 (:input :type "hidden" :name "topic-id" :value (getf topic :id))
                                 (:input :type "hidden" :name "category-slug" :value (getf topic :category-slug))
                                 (:button :class "delete-btn" :type "submit" (cl-who:str (tr :delete-topic)))))))
                 (:div :class "post-list"
                       (loop for (pid body created-at username role)
                             in posts
                             do (cl-who:htm
                                 (:div :class "post-card"
                                       (:div :class "post-header"
                                             (:a :class "post-author" :href (format nil "/user/~A" username)
                                                 (cl-who:str username))
                                             (when (or (string= role "admin")
                                                       (string= role "moderator"))
                                               (cl-who:htm
                                                (:span :class (format nil "role-badge role-~A" role)
                                                        (cl-who:str role))))
                                             (:span :class "post-date" (cl-who:str created-at)))
                                       (:div :class "post-body md-content" (cl-who:str body))
                                       (when (and user (or (user-moderator-p user)
                                                           (= (getf user :id) (getf topic :user-id))))
                                         (cl-who:htm
                                          (:div :class "post-actions"
                                                (:form :method "POST" :action "/delete-post"
                                                       :onsubmit (format nil "return confirm('~A')" (tr :confirm-delete-post))
                                                       (:input :type "hidden" :name "post-id" :value pid)
                                                       (:input :type "hidden" :name "topic-id"
                                                               :value (getf topic :id))
                                                       (:button :class "delete-btn" :type "submit"
                                                                (cl-who:str (tr :delete-post)))))))))))
                  (when user
                    (when throttled
                      (cl-who:htm
                       (:div :class "muted-notice" (cl-who:str (tr :throttled-notice)))))
                    (if (is-muted-p (session-user-id user))
                       (cl-who:htm
                        (:div :class "muted-notice"
                              (cl-who:str (tr :muted-notice))
                              (:strong (cl-who:str (format nil "~A" (getf user :muted-until))))))
                       (cl-who:htm
                        (:div :class "post-form-section"
                              (:h3 (cl-who:str (tr :reply)))
                              (:form :method "POST" :action "/new-post"
                                      (:input :type "hidden" :name "topic-id"
                                              :value (getf topic :id))
                                       (cl-who:str (forum-render-editor "body" (tr :reply-placeholder)))
                                       (:button :class "try-button" :type "submit"
                                                 (cl-who:str (tr :submit))))))))))
        (:footer (:p (:a :href "https://github.com/turtle-bazon/lisper-site" "lisper")
                      " &copy; 2026 | GPL-3.0")))))))
        (forum-page-not-found user))))

(defun forum-page-new-topic (user category-slug &optional throttled)
  (let ((categories (get-categories))
        (selected-cat (when category-slug
                        (get-category-by-slug category-slug))))
    (cl-who:with-html-output-to-string (s nil :prologue "<!DOCTYPE html>")
      (cl-who:htm
       (:html :lang *lang*
        (:head (cl-who:str (forum-render-head (tr :new-topic-title))))
        (:body
         (:div :class "container"
          (:header (cl-who:str (forum-render-header user)))
          (:div :class "section"
           (:a :class "back-link" :href "/forum" (cl-who:str (tr :back-to-forum)))
           (:h2 (cl-who:str (tr :new-topic)))
           (when throttled
             (cl-who:htm
              (:div :class "muted-notice" (cl-who:str (tr :throttled-notice)))))
           (if user
               (cl-who:htm
                (:form :method "POST" :action "/new-topic"
                       (:div :class "form-group"
                             (:label :for "category" (cl-who:str (tr :category)))
                             (:select :name "category" :id "category" :required "required"
                                      (loop for (id name slug desc sort) in categories
                                            do (cl-who:htm
                                                (:option :value slug
                                                         :selected (when (and selected-cat
                                                                              (string= slug category-slug))
                                                                     "selected")
                                                         (cl-who:str name))))))
                       (:div :class "form-group"
                             (:label :for "title" (cl-who:str (tr :title-field)))
                             (:input :type "text" :name "title" :id "title"
                                     :required "required" :placeholder (tr :title-placeholder)))
                       (:div :class "form-group"
                              (:label :for "body" (cl-who:str (tr :body-field)))
                              (cl-who:str (forum-render-editor "body" (tr :body-placeholder))))
                       (:button :class "try-button" :type "submit" (cl-who:str (tr :create-topic)))))
               (cl-who:htm
                (:p (cl-who:str (tr :login-to-create))
                    (:a :href "/login" (cl-who:str (tr :login))))))))
          (:footer (:p (:a :href "https://github.com/turtle-bazon/lisper-site" "lisper")
                        " &copy; 2026 | GPL-3.0"))))))))

(defun forum-page-not-found (user)
  (cl-who:with-html-output-to-string (s nil :prologue "<!DOCTYPE html>")
    (cl-who:htm
     (:html :lang *lang*
      (:head (cl-who:str (forum-render-head "404")))
      (:body
       (:div :class "container"
        (:header (cl-who:str (forum-render-header user)))
        (:div :class "section"
         (:h2 (cl-who:str (tr :not-found)))
         (:p (cl-who:str (tr :not-found-text)))
         (:a :class "try-button" :href "/forum" (cl-who:str (tr :go-to-forum)))))
       (:footer (:p (:a :href "https://github.com/turtle-bazon/lisper-site" "lisper")
                     " &copy; 2026 | GPL-3.0")))))))

(defun forum-page-user (name user)
  (let ((u (get-user-by-name name)))
    (if u
        (let ((topic-count (get-user-topic-count (getf u :id)))
              (post-count (get-user-post-count (getf u :id))))
          (cl-who:with-html-output-to-string (s nil :prologue "<!DOCTYPE html>")
            (cl-who:htm
             (:html :lang *lang*
              (:head (cl-who:str (forum-render-head (tr-format :profile-title name))))
              (:body
               (:div :class "container"
                (:header (cl-who:str (forum-render-header user)))
                (:div :class "section"
                 (:h2 (cl-who:str name))
                 (:div :class "profile-info"
                  (:p (cl-who:str (tr :role-label)) (:strong (cl-who:str (getf u :role))))
                  (:p (cl-who:str (tr :topics-label)) (:span (cl-who:str (format nil "~A" topic-count))))
                  (:p (cl-who:str (tr :posts-label)) (:span (cl-who:str (format nil "~A" post-count)))))
                 (when (and user (user-moderator-p user))
                   (cl-who:htm
                    (:div :class "mod-panel"
                     (:h3 (cl-who:str (tr :moderation)))
                     (if (is-muted-p (getf u :id))
                         (cl-who:htm
                          (:p :class "muted-status"
                              (cl-who:str (tr :muted-until))
                              (:strong (cl-who:str (format nil "~A" (getf u :muted-until)))))
                          (:form :method "POST" :action "/admin/unmute" :style "display:inline"
                           (:input :type "hidden" :name "user-id" :value (getf u :id))
                           (:input :type "hidden" :name "back"
                                   :value (format nil "/user/~A" name))
                           (:button :class "unmute-btn" :type "submit" (cl-who:str (tr :unmute)))))
                         (cl-who:htm
                          (:form :method "POST" :action "/admin/mute" :style "display:inline"
                           (:input :type "hidden" :name "user-id" :value (getf u :id))
                           (:input :type "hidden" :name "back"
                                   :value (format nil "/user/~A" name))
                           (:label (cl-who:str (tr :mute-for)))
                           (:select :name "duration"
                            (:option :value "1 hour" (cl-who:str (tr :dur-1h)))
                            (:option :value "1 day" (cl-who:str (tr :dur-1d)))
                            (:option :value "3 days" (cl-who:str (tr :dur-3d)))
                            (:option :value "1 week" (cl-who:str (tr :dur-1w)))
                            (:option :value "1 month" (cl-who:str (tr :dur-1m))))
                           (:button :class "mute-btn" :type "submit" (cl-who:str (tr :mute))))))
                     (when (and (user-admin-p user)
                                (not (= (getf user :id) (getf u :id))))
                       (cl-who:htm
                        (:div :class "role-change"
                         (:h4 (cl-who:str (tr :change-role)))
                         (:form :method "POST" :action "/admin/set-role"
                          (:input :type "hidden" :name "user-id" :value (getf u :id))
                          (:input :type "hidden" :name "back"
                                  :value (format nil "/user/~A" name))
                          (:select :name "role"
                           (dolist (r '("user" "moderator" "admin"))
                             (cl-who:htm
                              (:option :value r
                               :selected (when (string= (getf u :role) r) "selected")
                               (cl-who:str r)))))
                           (:button :class "role-btn" :type "submit" (cl-who:str (tr :assign)))))))))))
(:footer (:p (:a :href "https://github.com/turtle-bazon/lisper-site" "lisper")
                       " &copy; 2026 | GPL-3.0"))))))))
        (forum-page-not-found user))))

(defun forum-page-admin-users (user)
  (let ((users (get-all-users))
        (forum-closed (forum-closed-p)))
    (cl-who:with-html-output-to-string (s nil :prologue "<!DOCTYPE html>")
      (cl-who:htm
       (:html :lang *lang*
        (:head (cl-who:str (forum-render-head (tr :admin-title))))
        (:body
         (:div :class "container"
          (:header (cl-who:str (forum-render-header user)))
          (:div :class "section"
           (:h2 (cl-who:str (tr :forum-management)))
           (:div :class "admin-forum-status"
            (:p (cl-who:str (tr :forum-status))
                (if forum-closed
                    (cl-who:htm (:span :class "status-closed" (cl-who:str (tr :status-closed))))
                    (cl-who:htm (:span :class "status-open" (cl-who:str (tr :status-open))))))
            (:form :method "POST" :action "/admin/toggle-forum" :style "display:inline"
                   (:button :type "submit" :class (if forum-closed "try-button" "admin-button-danger")
                            (cl-who:str (if forum-closed (tr :open-forum) (tr :close-forum)))))))
          (:div :class "section"
           (:h2 (cl-who:str (tr :user-management)))
           (:div :class "admin-user-list"
            (loop for u in users
                  do (cl-who:htm
                      (:div :class "admin-user-row"
                       (:a :class "admin-user-name"
                           :href (format nil "/user/~A" (getf u :username))
                           (cl-who:str (getf u :username)))
                       (:span :class (format nil "role-badge role-~A" (getf u :role))
                              (cl-who:str (getf u :role)))
                       (when (is-muted-p (getf u :id))
                         (cl-who:htm
                          (:span :class "muted-badge"
                                 (cl-who:str (tr :muted-badge))
                                 (cl-who:str (format nil "~A" (getf u :muted-until)))))))))))
         (:footer (:p (:a :href "https://github.com/turtle-bazon/lisper-site" "lisper")
                       " &copy; 2026 | GPL-3.0")))))))))

(defun analytics-truncate (string &optional (limit 45))
  (when string
    (if (> (length string) limit)
        (concatenate 'string (subseq string 0 limit) "…")
        string)))

(defun analytics-device-label (device)
  "Перевод хранящихся в БД меток устройств ('Мобильные'/'Десктоп')."
  (cond ((string= device "Мобильные") (tr :device-mobile))
        ((string= device "Десктоп") (tr :device-desktop))
        (t device)))

(defun analytics-country-label (country)
  "Перевод 'Неизвестно' из БД."
  (if (string= country "Неизвестно") (tr :unknown) country))

(defun analytics-ua-label (label)
  "Перевод 'Другое' из БД (браузеры/ОС)."
  (if (string= label "Другое") (tr :unknown) label))

(defun forum-page-analytics (user &optional (bot-filter :all) (own-hosts nil)
                                      (tab-base "/admin/analytics"))
  (cl-who:with-html-output-to-string (s nil :prologue "<!DOCTYPE html>")
    (cl-who:htm
     (:html :lang *lang*
      (:head (cl-who:str (forum-render-head (tr :analytics-title))))
      (:body
       (:div :class "container"
        (:header (cl-who:str (forum-render-header user)))
        (:div :class "section"
         (:h2 (cl-who:str (tr :analytics-h2)))
         (:div :class "analytics-tabs"
          (:a :class (if (eq bot-filter :all) "analytics-tab active" "analytics-tab")
              :href (format nil "~A?tab=all" tab-base)
              (cl-who:str (tr :filter-all)))
          (:a :class (if (eq bot-filter :people) "analytics-tab active" "analytics-tab")
              :href (format nil "~A?tab=people" tab-base)
              (cl-who:str (tr :filter-people))))
         (:div :class "analytics-grid"
          (:div :class "stat-card"
           (:div :class "stat-value" (cl-who:str (format nil "~A" (analytics-total-views bot-filter))))
            (:div :class "stat-label" (cl-who:str (tr :total-views))))
            (:div :class "stat-card"
            (:div :class "stat-value" (cl-who:str (format nil "~A" (analytics-views-since bot-filter 24))))
            (:div :class "stat-label" (cl-who:str (tr :views-24h))))
           (:div :class "stat-card"
            (:div :class "stat-value" (cl-who:str (format nil "~A" (analytics-unique-since bot-filter 24))))
            (:div :class "stat-label" (cl-who:str (tr :unique-24h))))
           (:div :class "stat-card"
            (:div :class "stat-value" (cl-who:str (format nil "~A" (analytics-views-since bot-filter 168))))
            (:div :class "stat-label" (cl-who:str (tr :views-7d))))
           (:div :class "stat-card"
            (:div :class "stat-value" (cl-who:str (format nil "~A" (analytics-unique-since bot-filter 168))))
            (:div :class "stat-label" (cl-who:str (tr :unique-7d))))
           (:div :class "stat-card"
            (:div :class "stat-value" (cl-who:str (format nil "~A" (analytics-people-unique-since 168))))
            (:div :class "stat-label" (cl-who:str (tr :people-7d))))
           (:div :class "stat-card"
            (:div :class "stat-value" (cl-who:str (format nil "~A" (analytics-bot-count-since 168))))
            (:div :class "stat-label" (cl-who:str (tr :bots-7d))))
           (:div :class "stat-card"
            (:div :class "stat-value" (cl-who:str (format nil "~A%" (analytics-people-share-since 168))))
            (:div :class "stat-label" (cl-who:str (tr :people-share)))))
         (:div :class "analytics-block"
          (:h3 (cl-who:str (tr :trend)))
          (let ((trend (analytics-daily-trend bot-filter)))
            (cl-who:htm
             (:div :class "trend-chart"
              (let ((max (loop for (day views) in trend maximize views)))
                (loop for (day views) in trend
                      do (cl-who:htm
                          (:div :class "trend-bar-wrap"
                           (:div :class "trend-bar-value"
                                (cl-who:str (format nil "~A" views)))
                           (:div :class "trend-bar"
                                :style (format nil "height: ~A%"
                                               (if (plusp max)
                                                   (round (* 100 (/ views max)))
                                                   0))
                                :title (format nil "~A: ~A" day views))
                           (:div :class "trend-bar-label" (cl-who:str day)))))))))
         (:div :class "analytics-block"
          (:h3 (cl-who:str (tr :top-pages)))
          (:table :class "analytics-table"
           (:thead (:tr (:th (cl-who:str (tr :page))) (:th (cl-who:str (tr :views)))))
           (:tbody
            (loop for (path count) in (analytics-top-paths bot-filter 168 10)
                  do (cl-who:htm
                      (:tr (:td (cl-who:str path))
                           (:td :class "analytics-num" (cl-who:str (format nil "~A" count)))))))))
         (:div :class "analytics-block"
          (:h3 (cl-who:str (tr :sources)))
          (:table :class "analytics-table"
           (:thead (:tr (:th (cl-who:str (tr :source))) (:th (cl-who:str (tr :referrals)))))
           (:tbody
            (loop for (ref count) in (analytics-top-referrers bot-filter own-hosts 168 10)
                  do (cl-who:htm
                      (:tr (:td (cl-who:str (analytics-truncate (or ref ""))))
                           (:td :class "analytics-num" (cl-who:str (format nil "~A" count)))))))))
         (:div :class "analytics-block"
          (:h3 (cl-who:str (tr :langs)))
          (:table :class "analytics-table"
           (:thead (:tr (:th (cl-who:str (tr :language))) (:th (cl-who:str (tr :views)))))
           (:tbody
            (loop for (lang count) in (analytics-top-langs bot-filter 10)
                  do (cl-who:htm
                      (:tr (:td (cl-who:str lang))
                           (:td :class "analytics-num" (cl-who:str (format nil "~A" count)))))))))
         (:div :class "analytics-block"
          (:h3 (cl-who:str (tr :countries)))
          (if (analytics-geo-loaded-p)
              (cl-who:htm
               (:table :class "analytics-table"
                (:thead (:tr (:th (cl-who:str (tr :country))) (:th (cl-who:str (tr :views)))))
                (:tbody
                 (loop for (country count) in (analytics-top-countries bot-filter 168 10)
                       do (cl-who:htm
                           (:tr (:td (cl-who:str (analytics-country-label country)))
                                (:td :class "analytics-num" (cl-who:str (format nil "~A" count)))))))))
              (cl-who:htm
               (:p :class "analytics-note"
                   (cl-who:str (tr :geo-not-loaded))))))
(:div :class "analytics-block"
           (:h3 (cl-who:str (tr :devices)))
           (:table :class "analytics-table"
            (:thead (:tr (:th (cl-who:str (tr :device-type))) (:th (cl-who:str (tr :views)))))
            (:tbody
             (loop for (device count) in (analytics-top-devices bot-filter 168 4)
                   do (cl-who:htm
                       (:tr (:td (cl-who:str (analytics-device-label device)))
                            (:td :class "analytics-num" (cl-who:str (format nil "~A" count)))))))))
          (:div :class "analytics-block"
           (:h3 (cl-who:str (tr :browsers)))
           (:table :class "analytics-table"
            (:thead (:tr (:th (cl-who:str (tr :browser))) (:th (cl-who:str (tr :views)))))
            (:tbody
             (loop for (browser count) in (analytics-top-browsers bot-filter 6)
                   do (cl-who:htm
                       (:tr (:td (cl-who:str (analytics-ua-label browser)))
                            (:td :class "analytics-num" (cl-who:str (format nil "~A" count)))))))))
          (:div :class "analytics-block"
           (:h3 (cl-who:str (tr :os)))
           (:table :class "analytics-table"
            (:thead (:tr (:th (cl-who:str (tr :os-name))) (:th (cl-who:str (tr :views)))))
            (:tbody
             (loop for (os count) in (analytics-top-os bot-filter 6)
                   do (cl-who:htm
                       (:tr (:td (cl-who:str (analytics-ua-label os)))
                            (:td :class "analytics-num" (cl-who:str (format nil "~A" count)))))))))
         (:div :class "analytics-block"
          (:h3 (cl-who:str (tr :recent-visits)))
          (:table :class "analytics-table"
           (:thead (:tr (:th (cl-who:str (tr :time))) (:th (cl-who:str (tr :page)))
                        (:th (cl-who:str (tr :ip))) (:th (cl-who:str (tr :country)))
                        (:th (cl-who:str (tr :referrer))) (:th (cl-who:str (tr :bot)))))
           (:tbody
            (loop for (path referrer ip country is-bot ua ts) in (analytics-recent bot-filter 30)
                  do (cl-who:htm
                      (:tr (:td (cl-who:str ts))
                           (:td (cl-who:str path))
                           (:td (cl-who:str (or ip "")))
                           (:td (cl-who:str (analytics-country-label (or country ""))))
                           (:td (cl-who:str (analytics-truncate (or referrer ""))))
                           (:td (cl-who:str (if is-bot "✓" ""))))))))))
        (:footer (:p (:a :href "https://github.com/turtle-bazon/lisper-site" "lisper")
                      " &copy; 2026 | GPL-3.0")))))))))

(defun forum-page-login (user error-message)
  (cl-who:with-html-output-to-string (s nil :prologue "<!DOCTYPE html>")
    (cl-who:htm
     (:html :lang *lang*
      (:head (cl-who:str (forum-render-head (tr :login-title))))
      (:body
       (:div :class "container"
        (:header (cl-who:str (forum-render-header user)))
        (:div :class "auth-section"
         (:h2 (cl-who:str (tr :login)))
         (when error-message
           (cl-who:htm
            (:div :class "auth-error" (cl-who:str error-message))))
         (:form :method "POST" :action "/login"
                (:input :type "hidden" :name "fts" :value (make-form-token))
                (:div :class "form-group"
                      (:label :for "email" (cl-who:str (tr :email-label)))
                      (:input :type "email" :name "email" :id "email" :required "required"))
                (:div :class "form-group"
                      (:label :for "password" (cl-who:str (tr :password-label)))
                      (:input :type "password" :name "password" :id "password"
                              :required "required"))
                (:button :class "try-button" :type "submit" (cl-who:str (tr :login))))
         (:p :class "auth-switch"
             (cl-who:str (tr :no-account)) " "
             (:a :href "/register" (cl-who:str (tr :register)))))
        (:footer (:p (:a :href "https://github.com/turtle-bazon/lisper-site" "lisper")
                      " &copy; 2026 | GPL-3.0"))))))))

(defun forum-page-register (user error-message)
  (cl-who:with-html-output-to-string (s nil :prologue "<!DOCTYPE html>")
    (cl-who:htm
     (:html :lang *lang*
      (:head (cl-who:str (forum-render-head (tr :register-title))))
      (:body
       (:div :class "container"
        (:header (cl-who:str (forum-render-header user)))
        (:div :class "auth-section"
         (:h2 (cl-who:str (tr :register)))
         (when error-message
           (cl-who:htm
            (:div :class "auth-error" (cl-who:str error-message))))
         (:form :method "POST" :action "/register"
                (let ((captcha (make-captcha)))
                  (cl-who:htm
                   (:input :type "hidden" :name "fts" :value (make-form-token))
                   (:div :class "form-group"
                         (:label :for "username" (cl-who:str (tr :username-label)))
                         (:input :type "text" :name "username" :id "username"
                                 :required "required" :minlength "3" :maxlength "20"))
                   (:div :class "form-group"
                         (:label :for "email" (cl-who:str (tr :email-label)))
                         (:input :type "email" :name "email" :id "email" :required "required"))
                   (:div :class "form-group"
                         (:label :for "password" (cl-who:str (tr :password-label)))
                         (:input :type "password" :name "password" :id "password"
                                 :required "required" :minlength "8"))
                   (:div :class "form-group"
                         (:label :for "captcha" (cl-who:str (tr-format :captcha-label (car captcha))))
                         (:input :type "text" :name "captcha" :id "captcha"
                                 :required "required" :autocomplete "off"
                                 :inputmode "numeric"))
                    (:input :type "hidden" :name "captcha-token" :value (cdr captcha))))
                ;; Honeypot: скрытое поле, боты его заполняют, люди — нет
                (:div :style "position:absolute;left:-9999px" :aria-hidden "true"
                      (:input :type "text" :name "website" :tabindex "-1" :autocomplete "off"))
                (:button :class "try-button" :type "submit" (cl-who:str (tr :register))))
         (:p :class "auth-switch"
             (cl-who:str (tr :have-account)) " "
             (:a :href "/login" (cl-who:str (tr :login)))))
        (:footer (:p (:a :href "https://github.com/turtle-bazon/lisper-site" "lisper")
                      " &copy; 2026 | GPL-3.0"))))))))
