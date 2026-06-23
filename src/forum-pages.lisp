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
    (:style (cl-who:str (generate-css)))))

(defun forum-render-header (user)
  (cl-who:with-html-output-to-string (s)
    (:div :class "logo-container"
     (cl-who:str *logo-svg*))
    (:div :class "header-buttons"
     (:a :class "forum-link" :href "/forum" "Форум")
     (:a :class "telegram-link" :href "tg://resolve?domain=commonlisp_ru" "Telegram")
     (if user
         (cl-who:htm
          (:span :class "user-info" (cl-who:str (session-username user)))
          (:a :class "logout-link" :href "/logout" "Выйти"))
         (cl-who:htm
          (:a :class "try-button" :href "/login" "Войти")
          (:a :class "login-link" :href "/register" "Регистрация"))))))

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
                       (:span "Автор: " (:strong (cl-who:str (getf topic :username))))
                       (:span (cl-who:str (format nil " · ~A" (getf topic :created-at)))))
                 (:div :class "post-list"
                       (loop for (pid body created-at username role)
                             in posts
                             do (cl-who:htm
                                 (:div :class "post-card"
                                       (:div :class "post-header"
                                             (:span :class "post-author" (cl-who:str username))
                                             (when (or (string= role "admin")
                                                       (string= role "moderator"))
                                               (cl-who:htm
                                                (:span :class (format nil "role-badge role-~A" role)
                                                        (cl-who:str role))))
                                             (:span :class "post-date" (cl-who:str created-at)))
                                       (:div :class "post-body" (cl-who:str body))
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
                   (cl-who:htm
                    (:div :class "post-form-section"
                          (:h3 "Ответить")
                          (:form :method "POST" :action "/new-post"
                                 (:input :type "hidden" :name "topic-id"
                                         :value (getf topic :id))
                                 (:textarea :name "body" :class "post-textarea"
                                            :placeholder "Ваш ответ..." :required "required")
                                 (:button :class "try-button" :type "submit"
                                           "Отправить")))))))
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
                             (:textarea :name "body" :id "body" :required "required"
                                        :placeholder "Сообщение..." :class "post-textarea"))
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
      (:head (cl-who:str (forum-render-head "404 — Форум")))
      (:body
       (:div :class "container"
        (:header (cl-who:str (forum-render-header user)))
        (:div :class "section"
         (:h2 "Страница не найдена")
         (:a :class "back-link" :href "/forum" "← Назад к форуму")))
       (:footer (:p (:a :href "https://github.com/turtle-bazon/lisper.ru" "lisper.ru")
                     " &copy; 2026 | GPL-3.0")))))))

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
         (when error-message
           (cl-who:htm
            (:div :class "auth-error" (cl-who:str error-message))))
         (:form :method "POST" :action "/login"
                (:div :class "form-group"
                      (:label :for "email" "Email")
                      (:input :type "email" :name "email" :id "email" :required "required"))
                (:div :class "form-group"
                      (:label :for "password" "Пароль")
                      (:input :type "password" :name "password" :id "password"
                              :required "required"))
                (:button :class "try-button" :type "submit" "Войти"))
         (:p :class "auth-switch"
             "Нет аккаунта? " (:a :href "/register" "Зарегистрироваться"))))
       (:footer (:p (:a :href "https://github.com/turtle-bazon/lisper.ru" "lisper.ru")
                     " &copy; 2026 | GPL-3.0")))))))

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
         (when error-message
           (cl-who:htm
            (:div :class "auth-error" (cl-who:str error-message))))
         (:form :method "POST" :action "/register"
                (:div :class "form-group"
                      (:label :for "username" "Имя пользователя")
                      (:input :type "text" :name "username" :id "username"
                              :required "required"))
                (:div :class "form-group"
                      (:label :for "email" "Email")
                      (:input :type "email" :name "email" :id "email" :required "required"))
                (:div :class "form-group"
                      (:label :for "password" "Пароль")
                      (:input :type "password" :name "password" :id "password"
                              :required "required" :minlength "6"))
                (:button :class "try-button" :type "submit" "Зарегистрироваться"))
         (:p :class "auth-switch"
             "Уже есть аккаунт? " (:a :href "/login" "Войти"))))
       (:footer (:p (:a :href "https://github.com/turtle-bazon/lisper.ru" "lisper.ru")
                     " &copy; 2026 | GPL-3.0")))))))
