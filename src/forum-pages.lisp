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
    (:link :rel "stylesheet" :href "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github-dark.min.css"
           :integrity "sha384-wH75j6z1lH97ZOpMOInqhgKzFkAInZPPSPlZpYKYTOqsaizPvhQZmAtLcPKXpLyH"
           :crossorigin "anonymous")
    (:style (cl-who:str (generate-css)))
    (:script :src "https://cdnjs.cloudflare.com/ajax/libs/dompurify/3.2.4/purify.min.js"
             :integrity "sha384-eEu5CTj3qGvu9PdJuS+YlkNi7d2XxQROAFYOr59zgObtlcux1ae1Il3u7jvdCSWu"
             :crossorigin "anonymous")
    (:script :src "https://cdnjs.cloudflare.com/ajax/libs/marked/12.0.0/marked.min.js"
             :integrity "sha384-NNQgBjjuhtXzPmmy4gurS5X7P4uTt1DThyevz4Ua0IVK5+kazYQI1W27JHjbbxQz"
             :crossorigin "anonymous")
    (:script :src "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"
             :integrity "sha384-F/bZzf7p3Joyp5psL90p/p89AZJsndkSoGwRpXcZhleCWhd8SnRuoYo4d0yirjJp"
             :crossorigin "anonymous")
    (:script :src "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/languages/lisp.min.js"
             :integrity "sha384-+LHHMbAXOUlvquvrQZ9LW4KeR2nwcsh/lpp7xrWu7KuaDSGgAYBIdm8qCw97I1tq"
             :crossorigin "anonymous")))

(defun forum-render-header (user)
  (cl-who:with-html-output-to-string (s)
    (:div :class "site-header"
     (:div :class "header-left"
      (:a :href "/" :class "header-logo"
       (cl-who:str *logo-svg*)))
     (:nav :class "header-nav"
      (:a :href "/" (:span :class "nav-icon" (cl-who:str "<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8'/><path d='M3 10a2 2 0 0 1 .709-1.528l7-6a2 2 0 0 1 2.582 0l7 6A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z'/></svg>")) " Главная")
      (:a :href "tg://resolve?domain=commonlisp_ru" (:span :class "nav-icon" (cl-who:str "<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 240 240'><circle cx='120' cy='120' r='120' fill='#229ED9'/><path d='M81.229,128.772l14.237,39.406s1.78,3.687,3.686,3.687,30.255-29.492,30.255-29.492l31.525-60.89L81.737,118.6Z' fill='#c8daea'/><path d='M100.106,138.878l-2.733,29.046s-1.144,8.9,7.754,0,17.415-15.763,17.415-15.763' fill='#a9c6d8'/><path d='M81.486,130.178,52.2,120.636s-3.5-1.42-2.373-4.64c.232-.664.7-1.229,2.1-2.2,6.489-4.523,120.106-45.36,120.106-45.36s3.208-1.081,5.1-.362a2.766,2.766,0,0,1,1.885,2.055,9.357,9.357,0,0,1,.254,2.585c-.009.752-.1,1.449-.169,2.542-.692,11.165-21.4,94.493-21.4,94.493s-1.239,4.876-5.678,5.043A8.13,8.13,0,0,1,146.1,172.5c-8.711-7.493-38.819-27.727-45.472-32.177a1.27,1.27,0,0,1-.546-.9c-.093-.469.417-1.05.417-1.05s52.426-46.6,53.821-51.492c.108-.379-.3-.566-.848-.4-3.482,1.281-63.844,39.4-70.506,43.607A3.21,3.21,0,0,1,81.486,130.178Z' fill='#fff'/></svg>")) " Telegram")
      (:a :href "/forum" (:span :class "nav-icon" (cl-who:str "<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M2.992 16.342a2 2 0 0 1 .094 1.167l-1.065 3.29a1 1 0 0 0 1.236 1.168l3.413-.998a2 2 0 0 1 1.099.092 10 10 0 1 0-4.777-4.719'/></svg>")) " Форум"))
     (:div :class "header-right"
      (if user
          (cl-who:htm
           (when (user-admin-p user)
             (cl-who:htm
              (:a :class "header-admin" :href "/admin/users" "Админ")))
           (:a :class "header-user" :href (format nil "/user/~A" (session-username user))
               (cl-who:str (session-username user)))
           (:a :class "header-logout" :href "/logout" "Выйти"))
          (cl-who:htm
           (:a :class "header-login" :href "/login" "Войти")
           (:a :class "header-register" :href "/register" "Регистрация")))))))

(defun forum-render-editor (name &optional (placeholder "Напишите что-нибудь..."))
  "Render a rich markdown editor with toolbar and preview."
  (cl-who:with-html-output-to-string (s)
    (:div :class "md-editor"
     (:div :class "md-toolbar"
      (:button :type "button" :class "md-btn" :data-action "bold" :title "Жирный" "B")
      (:button :type "button" :class "md-btn" :data-action "italic" :title "Курсив" "I")
      (:button :type "button" :class "md-btn" :data-action "strike" :title "Зачёркнутый" "S")
      (:span :class "md-sep")
      (:button :type "button" :class "md-btn" :data-action "h1" :title "Заголовок 1" "H1")
      (:button :type "button" :class "md-btn" :data-action "h2" :title "Заголовок 2" "H2")
      (:button :type "button" :class "md-btn" :data-action "h3" :title "Заголовок 3" "H3")
      (:span :class "md-sep")
      (:button :type "button" :class "md-btn" :data-action "ul" :title "Список" "• —")
      (:button :type "button" :class "md-btn" :data-action "ol" :title "Нумерованный список" "1.")
      (:button :type "button" :class "md-btn" :data-action "quote" :title "Цитата" "« »")
      (:span :class "md-sep")
      (:button :type "button" :class "md-btn" :data-action "code" :title "Код" "&lt;/&gt;")
      (:button :type "button" :class "md-btn" :data-action "link" :title "Ссылка" "🔗")
      (:button :type "button" :class "md-btn" :data-action "image" :title "Картинка" "🖼")
      (:span :class "md-sep")
      (:button :type "button" :class "md-btn md-preview-btn" :data-action "preview" :title "Предпросмотр" "👁"))
     (:textarea :name name :class "md-textarea" :placeholder placeholder
                :required "required")
     (:div :class "md-preview" :style "display:none"))))

(defun forum-page-index (user)
  (let ((categories (get-categories))
        (recent (get-recent-topics 10)))
    (cl-who:with-html-output-to-string (s nil :prologue "<!DOCTYPE html>")
      (cl-who:htm
       (:html :lang "ru"
        (:head (cl-who:str (forum-render-head "Форум — Common Lisp")))
        (:body
         (:div :class "container"
          (:header (cl-who:str (forum-render-header user)))
          (:div :class "section"
           (:h2 "Форум")
           (when user
             (cl-who:htm
              (:div :class "forum-actions"
                    (:a :class "try-button" :href "/new-topic" "Новая тема"))))
           (:div :class "forum-categories"
                 (loop for (id name slug desc) in categories
                       do (cl-who:htm
                           (:div :class "forum-cat-card"
                                 (:a :class "forum-cat-link"
                                     :href (format nil "/forum/~A" slug)
                                     (:h3 (cl-who:str name))
                                     (:p (cl-who:str desc))
                                     (:span :class "forum-cat-count"
                                            (cl-who:str (format nil "~A тем" (topic-count id)))))))))
           (:div :class "section"
                 (:h2 "Последние темы")
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
                                                        (format nil "~A ответов · ~A" post-count cat-name)))))))))
                     (cl-who:htm
                      (:p :class "empty-state" "Пока нет тем. Будьте первым!")))))
           (:footer (:p (:a :href "https://github.com/turtle-bazon/lisper.ru" "lisper.ru")
                        " &copy; 2026 | GPL-3.0")))))))))

(defun forum-page-category (category user)
  (let ((cat (get-category-by-slug category)))
    (if cat
        (let ((topics (get-topics (getf cat :id))))
          (cl-who:with-html-output-to-string (s nil :prologue "<!DOCTYPE html>")
            (cl-who:htm
             (:html :lang "ru"
              (:head (cl-who:str (forum-render-head (format nil "~A — Форум" (getf cat :name)))))
              (:body
               (:div :class "container"
                (:header (cl-who:str (forum-render-header user)))
                (:div :class "section"
                 (:a :class "back-link" :href "/forum" "← Назад к форуму")
                 (:h2 (cl-who:str (getf cat :name)))
                 (:p :class "section-sub" (cl-who:str (getf cat :description)))
                 (when user
                   (cl-who:htm
                    (:a :class "try-button" :href
                        (format nil "/new-topic?category=~A" (getf cat :slug))
                        "Новая тема")))
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
                                                        (format nil "~A ответов · ~A · ~A"
                                                                 post-count username last-post-at)))))))))
                     (cl-who:htm
                      (:p :class "empty-state" "Пока нет тем в этой категории.")))))
               (:footer (:p (:a :href "https://github.com/turtle-bazon/lisper.ru" "lisper.ru")
                             " &copy; 2026 | GPL-3.0")))))))
        (forum-page-not-found user))))

(defun forum-page-topic (topic-id user)
  (let ((topic (get-topic topic-id)))
    (if topic
        (let ((posts (get-posts topic-id)))
          (cl-who:with-html-output-to-string (s nil :prologue "<!DOCTYPE html>")
            (cl-who:htm
             (:html :lang "ru"
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
                       (:span "Автор: ")
                       (:a :class "post-author" :href (format nil "/user/~A" (getf topic :username))
                           (cl-who:str (getf topic :username)))
                       (:span (cl-who:str (format nil " · ~A" (getf topic :created-at)))))
                 (when (and user (user-moderator-p user))
                   (cl-who:htm
                    (:div :class "topic-moderation"
                          (:form :method "POST" :action "/delete-topic" :style "display:inline"
                                 :onsubmit "return confirm('Удалить тему со всеми сообщениями?')"
                                 (:input :type "hidden" :name "topic-id" :value (getf topic :id))
                                 (:input :type "hidden" :name "category-slug" :value (getf topic :category-slug))
                                 (:button :class "delete-btn" :type "submit" "Удалить тему")))))
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
                                                       :onsubmit "return confirm('Удалить пост?')"
                                                       (:input :type "hidden" :name "post-id" :value pid)
                                                       (:input :type "hidden" :name "topic-id"
                                                               :value (getf topic :id))
                                                       (:button :class "delete-btn" :type "submit"
                                                                "Удалить")))))))))
                 (when user
                   (if (is-muted-p (session-user-id user))
                       (cl-who:htm
                        (:div :class "muted-notice"
                              "Вы не можете писать. Мут до "
                              (:strong (cl-who:str (format nil "~A" (getf user :muted-until))))))
                       (cl-who:htm
                        (:div :class "post-form-section"
                              (:h3 "Ответить")
                              (:form :method "POST" :action "/new-post"
                                      (:input :type "hidden" :name "topic-id"
                                              :value (getf topic :id))
                                       (cl-who:str (forum-render-editor "body" "Ваш ответ..."))
                                       (:button :class "try-button" :type "submit"
                                                 "Отправить"))))))))
        (:footer (:p (:a :href "https://github.com/turtle-bazon/lisper.ru" "lisper.ru")
                      " &copy; 2026 | GPL-3.0")))))))
        (forum-page-not-found user))))

(defun forum-page-new-topic (user category-slug)
  (let ((categories (get-categories))
        (selected-cat (when category-slug
                        (get-category-by-slug category-slug))))
    (cl-who:with-html-output-to-string (s nil :prologue "<!DOCTYPE html>")
      (cl-who:htm
       (:html :lang "ru"
        (:head (cl-who:str (forum-render-head "Новая тема — Форум")))
        (:body
         (:div :class "container"
          (:header (cl-who:str (forum-render-header user)))
          (:div :class "section"
           (:a :class "back-link" :href "/forum" "← Назад к форуму")
           (:h2 "Новая тема")
           (if user
               (cl-who:htm
                (:form :method "POST" :action "/new-topic"
                       (:div :class "form-group"
                             (:label :for "category" "Категория")
                             (:select :name "category" :id "category" :required "required"
                                      (loop for (id name slug desc sort) in categories
                                            do (cl-who:htm
                                                (:option :value slug
                                                         :selected (when (and selected-cat
                                                                              (string= slug category-slug))
                                                                         "selected")
                                                         (cl-who:str name))))))
                       (:div :class "form-group"
                             (:label :for "title" "Заголовок")
                             (:input :type "text" :name "title" :id "title"
                                     :required "required" :placeholder "Тема"))
                       (:div :class "form-group"
                              (:label :for "body" "Текст")
                              (cl-who:str (forum-render-editor "body" "Сообщение...")))
                       (:button :class "try-button" :type "submit" "Создать тему")))
               (cl-who:htm
                (:p "Войдите, чтобы создать тему. "
                    (:a :href "/login" "Войти"))))))
         (:footer (:p (:a :href "https://github.com/turtle-bazon/lisper.ru" "lisper.ru")
                       " &copy; 2026 | GPL-3.0"))))))))

(defun forum-page-not-found (user)
  (cl-who:with-html-output-to-string (s nil :prologue "<!DOCTYPE html>")
    (cl-who:htm
     (:html :lang "ru"
      (:head (cl-who:str (forum-render-head "404")))
      (:body
       (:div :class "container"
        (:header (cl-who:str (forum-render-header user)))
        (:div :class "section"
         (:h2 "Страница не найдена")
         (:p "Запрашиваемая страница не существует.")
         (:a :class "try-button" :href "/forum" "На форум")))
       (:footer (:p (:a :href "https://github.com/turtle-bazon/lisper.ru" "lisper.ru")
                     " &copy; 2026 | GPL-3.0")))))))

(defun forum-page-user (name user)
  (let ((u (get-user-by-name name)))
    (if u
        (let ((topic-count (get-user-topic-count (getf u :id)))
              (post-count (get-user-post-count (getf u :id))))
          (cl-who:with-html-output-to-string (s nil :prologue "<!DOCTYPE html>")
            (cl-who:htm
             (:html :lang "ru"
              (:head (cl-who:str (forum-render-head (format nil "~A — Профиль" name))))
              (:body
               (:div :class "container"
                (:header (cl-who:str (forum-render-header user)))
                (:div :class "section"
                 (:h2 (cl-who:str name))
                 (:div :class "profile-info"
                  (:p "Роль: " (:strong (cl-who:str (getf u :role))))
                  (:p "Тем: " (:span (cl-who:str (format nil "~A" topic-count))))
                  (:p "Сообщений: " (:span (cl-who:str (format nil "~A" post-count)))))
                 (when (and user (user-moderator-p user))
                   (cl-who:htm
                    (:div :class "mod-panel"
                     (:h3 "Модерация")
                     (if (is-muted-p (getf u :id))
                         (cl-who:htm
                          (:p :class "muted-status"
                              "Замьючен до "
                              (:strong (cl-who:str (format nil "~A" (getf u :muted-until)))))
                          (:form :method "POST" :action "/admin/unmute" :style "display:inline"
                           (:input :type "hidden" :name "user-id" :value (getf u :id))
                           (:input :type "hidden" :name "back"
                                   :value (format nil "/user/~A" name))
                           (:button :class "unmute-btn" :type "submit" "Снять мут")))
                         (cl-who:htm
                          (:form :method "POST" :action "/admin/mute" :style "display:inline"
                           (:input :type "hidden" :name "user-id" :value (getf u :id))
                           (:input :type "hidden" :name "back"
                                   :value (format nil "/user/~A" name))
                           (:label "Мут на: ")
                           (:select :name "duration"
                            (:option :value "1 hour" "1 час")
                            (:option :value "1 day" "1 день")
                            (:option :value "3 days" "3 дня")
                            (:option :value "1 week" "Неделю")
                            (:option :value "1 month" "Месяц"))
                           (:button :class "mute-btn" :type "submit" "Замутить"))))
                     (when (and (user-admin-p user)
                                (not (= (getf user :id) (getf u :id))))
                       (cl-who:htm
                        (:div :class "role-change"
                         (:h4 "Изменить роль")
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
                           (:button :class "role-btn" :type "submit" "Назначить")))))))))
                 (:footer (:p (:a :href "https://github.com/turtle-bazon/lisper.ru" "lisper.ru")
                       " &copy; 2026 | GPL-3.0"))))))))
        (forum-page-not-found user))))

(defun forum-page-admin-users (user)
  (let ((users (get-all-users))
        (forum-closed (forum-closed-p)))
    (cl-who:with-html-output-to-string (s nil :prologue "<!DOCTYPE html>")
      (cl-who:htm
       (:html :lang "ru"
        (:head (cl-who:str (forum-render-head "Админ — Форум")))
        (:body
         (:div :class "container"
          (:header (cl-who:str (forum-render-header user)))
          (:div :class "section"
           (:h2 "Управление форумом")
           (:div :class "admin-forum-status"
            (:p "Статус форума: "
                (if forum-closed
                    (cl-who:htm (:span :class "status-closed" "ЗАКРЫТ"))
                    (cl-who:htm (:span :class "status-open" "ОТКРЫТ"))))
            (:form :method "POST" :action "/admin/toggle-forum" :style "display:inline"
                   (:button :type "submit" :class (if forum-closed "try-button" "admin-button-danger")
                            (if forum-closed "Открыть форум" "Закрыть форум")))))
          (:div :class "section"
           (:h2 "Управление пользователями")
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
                                 "Мут до "
                                 (cl-who:str (format nil "~A" (getf u :muted-until)))))))))))
         (:footer (:p (:a :href "https://github.com/turtle-bazon/lisper.ru" "lisper.ru")
                       " &copy; 2026 | GPL-3.0")))))))))

(defun forum-page-login (user error-message)
  (cl-who:with-html-output-to-string (s nil :prologue "<!DOCTYPE html>")
    (cl-who:htm
     (:html :lang "ru"
      (:head (cl-who:str (forum-render-head "Вход — Форум")))
      (:body
       (:div :class "container"
        (:header (cl-who:str (forum-render-header user)))
        (:div :class "auth-section"
         (:h2 "Вход")
         (:div :class "auth-error" (cl-who:str (or error-message "Вход временно отключён. Скоро будет доступен вход через VK ID, Yandex ID и Госуслуги.")))
         (:p :style "color:#888;margin-top:16px"
             "Сейчас на сайте нельзя зарегистрироваться или войти через email."))
        (:footer (:p (:a :href "https://github.com/turtle-bazon/lisper.ru" "lisper.ru")
                      " &copy; 2026 | GPL-3.0"))))))))

(defun forum-page-register (user error-message)
  (cl-who:with-html-output-to-string (s nil :prologue "<!DOCTYPE html>")
    (cl-who:htm
     (:html :lang "ru"
      (:head (cl-who:str (forum-render-head "Регистрация — Форум")))
      (:body
       (:div :class "container"
        (:header (cl-who:str (forum-render-header user)))
        (:div :class "auth-section"
         (:h2 "Регистрация")
         (:div :class "auth-error" (cl-who:str (or error-message "Регистрация временно отключена. Скоро будет доступен вход через VK ID, Yandex ID и Госуслуги.")))
         (:p :style "color:#888;margin-top:16px"
             "Сейчас на сайте нельзя зарегистрироваться или войти через email."))
        (:footer (:p (:a :href "https://github.com/turtle-bazon/lisper.ru" "lisper.ru")
                      " &copy; 2026 | GPL-3.0"))))))))
