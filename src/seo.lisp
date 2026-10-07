;;; SEO-инфраструктура: robots.txt, sitemap.xml, RSS, 301-редиректы
;;; со старых URL lisper.ru, JSON-LD.
;;;
;;; Абсолютные URL (canonical, hreflang, og:url, RSS, sitemap, JSON-LD,
;;; Location у 301) строятся от ДОМЕНА ТЕКУЩЕГО ЗАПРОСА, если он есть в
;;; белом списке :site-hosts, иначе от конфига :site-url. Так lisper.ru и
;;; lisper.nl каждая отдаёт self-referencing canonical/og:url, а неизвестный
;;; Host (краулер, прокси, сканер) не может подмешать свой домен.

(in-package :lisper)

(defun configured-site-url ()
  "URL сайта из конфига :site-url без завершающего слэша. Fallback и
   единственный источник для вывода без запроса (CLI)."
  (string-right-trim "/" (or (config :site-url) "http://lisper.ru")))

(defparameter *site-url* nil
  "Домен текущего запроса (bind в make-app). NIL — вне запроса.")

(defun site-url ()
  "Домен текущего запроса или конфиг :site-url."
  (or *site-url* (configured-site-url)))

;;; --- домен из заголовков запроса ----------------------------------------

(defun strip-host-port (host)
  "Хост без порта: \"lisper.nl:8081\" → \"lisper.nl\", \"[::1]:8080\" → \"::1\".
   Возвращает строку в нижнем регистре с обрезанными пробелами."
  (when host
    (let* ((h (string-trim '(#\Space #\Tab) (string-downcase host)))
           (h (if (and (plusp (length h)) (char= (char h 0) #\[))
                  (let ((close (position #\] h)))
                    (if close (subseq h 1 close) h))
                  h)))
      (let ((colon (position #\: h)))
        (if (and colon (> colon 0)) (subseq h 0 colon) h)))))

(defun first-forwarded-value (v)
  "Первый хоп списка \"a, b, c\" (X-Forwarded-Proto / -Host)."
  (when v
    (let* ((s (string-trim '(#\Space #\Tab) v))
           (comma (position #\, s)))
      (string-trim '(#\Space #\Tab) (if comma (subseq s 0 comma) s)))))

(defun allowed-site-hosts ()
  "Белый список доменов из конфига :site-hosts. NIL → только домен из
   :site-url (режим одного домена, поведение до 2026-10-05)."
  (let ((hosts (config :site-hosts)))
    (if hosts
        (remove-duplicates
         (remove nil (mapcar #'strip-host-port hosts))
         :test #'string=)
        (list (strip-host-port (configured-site-url))))))

(defun url-scheme (url)
  "Схема из URL или NIL."
  (when (and url (plusp (min (length url) 8)))
    (when (string= (subseq url 0 8) "https://") "https")))

(defun request-scheme (env fallback-scheme)
  "Схема текущего запроса: X-Forwarded-Proto (её задаёт терминирующий TLS
   прокси), иначе схема из конфига."
  (let ((xfp (first-forwarded-value (i18n-header env "x-forwarded-proto"))))
    (cond ((and xfp (plusp (length xfp))) (string-downcase xfp))
          (t (or fallback-scheme "http")))))

(defun request-site-url (env)
  "Домен текущего запроса как origin (без слэша) для абсолютных URL.
   Берётся X-Forwarded-Host (первый хоп), иначе Host; домен берётся ТОЛЬКО
   если он в :site-hosts — иначе возвращается configured-site-url."
  (let* ((cfg (configured-site-url))
         (raw (or (first-forwarded-value (i18n-header env "x-forwarded-host"))
                  (i18n-header env "host")))
         (host (strip-host-port raw)))
    (if (and host (member host (allowed-site-hosts) :test #'string=))
        (format nil "~A://~A" (request-scheme env (url-scheme cfg)) host)
        cfg)))

;;; --- нормализация путей для редиректов ---------------------------------

(defun strip-suffix-ci (s suffix)
  (if (and (>= (length s) (length suffix))
           (string-equal suffix (subseq s (- (length s) (length suffix)))))
      (subseq s 0 (- (length s) (length suffix)))
      s))

(defun normalize-seo-path (path)
  "Ключ поиска редиректа: без хвостового '/' и '.html', в нижнем регистре
   (string-downcase трогает только ASCII — кириллица не страдает)."
  (let* ((p (string-right-trim "/" (or path "")))
         (p (strip-suffix-ci p ".html")))
    (if (string= p "") "/" (string-downcase p))))

(defun seo/insert-redirect (old-path new-path)
  "Добавляет вариант old_path -> new_path (дубликаты игнорируются).
   NIL и мусорные пути пропускаются."
  (when (and old-path new-path
             (plusp (length old-path))
             (not (string= (normalize-seo-path old-path) "/")))
    (handler-case
        (postmodern:execute
         "INSERT INTO redirects (old_path, new_path) VALUES ($1,$2)
          ON CONFLICT (old_path) DO NOTHING"
         (normalize-seo-path old-path) new-path)
      (error (e)
        (format *error-output* "~&redirect insert FAIL ~a: ~a~%" old-path e)))))

(defun redirect-for-path (raw-path)
  "Новый путь для старого URL или NIL. Пробует варианты: как пришло,
   один percent-decode, двойной decode (wayback любил двойное кодирование)."
  (when raw-path
    (let ((variants (list (normalize-seo-path raw-path))))
      (handler-case
          (push (normalize-seo-path (url-decode raw-path)) variants)
        (error () nil))
      (loop for v in (remove-duplicates variants :test #'string=)
            do (let ((new (postmodern:query
                           "SELECT new_path FROM redirects WHERE old_path = $1"
                           v :single)))
                 (when new (return-from redirect-for-path new)))))))

(defun seo/maybe-redirect (path)
  "Ответ 301 для legacy-URL или NIL. Динамические правила:
     /forum/thread/<id>[/pageN] -> /topic/<id>
     /feeds/*                   -> /rss"
  (let* ((tid (cl-ppcre:register-groups-bind (id)
                  ("^/forum/thread/(\\d+)" path)
                (parse-integer id))))
    (cond
      (tid
       `(301 (:location ,(format nil "/topic/~D" tid)
               :content-type "text/plain; charset=utf-8")
              ("")))
      ((cl-ppcre:scan "^/feeds/" path)
       `(301 (:location ,(format nil "~A/rss" (site-url))
               :content-type "text/plain; charset=utf-8")
              ("")))
      (t
       (let ((new (redirect-for-path path)))
         (when new
           (if (and (plusp (length new)) (char= (char new 0) #\/))
               `(301 (:location ,new
                       :content-type "text/plain; charset=utf-8")
                      (""))
               ;; страховка от кривых данных в таблице
               `(301 (:location ,(format nil "~A~A" (site-url) new)
                       :content-type "text/plain; charset=utf-8")
                      ("")))))))))

;;; --- robots.txt ---------------------------------------------------------

(defun robots-txt ()
  (format nil "User-agent: *~%
~{Disallow: ~A~%~}
Sitemap: ~A/sitemap.xml
"
          '("/admin" "/login" "/register" "/logout" "/set-lang"
            "/analytics/" "/jscl" "/game-source/" "/tool-source/"
            "/i18n.js")
          (site-url)))

;;; --- даты ---------------------------------------------------------------

(defun dmy-to-iso (s)
  "\"17.08.2010 04:15\" -> \"2010-08-17T04:15:00\" (для JSON-LD)."
  (when s
    (cl-ppcre:register-groups-bind (dd mm yyyy hh mi)
        ("(\\d{2})\\.(\\d{2})\\.(\\d{4})(?:\\s+(\\d{1,2}):(\\d{2}))?" s)
      (format nil "~4,'0d-~2,'0d-~2,'0dT~2,'0d:~2,'0d:00"
              (parse-integer yyyy) (parse-integer mm) (parse-integer dd)
              (if hh (parse-integer hh) 0)
              (if mi (parse-integer mi) 0)))))

(defun json-escape (s)
  (when s
    (setf s (cl-ppcre:regex-replace-all "\\\\" s "\\\\\\\\"))
    (setf s (cl-ppcre:regex-replace-all "\"" s "\\\\\\\""))
    (setf s (cl-ppcre:regex-replace-all (string #\Newline) s " "))
    s))

;;; --- sitemap.xml --------------------------------------------------------

(defun seo/blog-sitemap-rows ()
  (postmodern:query
   "SELECT '/blog/' || u.username || '/' || b.slug,
           TO_CHAR(b.updated_at, 'YYYY-MM-DD')
      FROM blog_posts b JOIN users u ON u.id = b.user_id
     ORDER BY b.created_at DESC"))

(defun seo/category-sitemap-rows ()
  (postmodern:query "SELECT '/forum/' || slug FROM categories ORDER BY sort_order"))

(defun seo/topic-sitemap-rows ()
  (postmodern:query
   "SELECT '/topic/' || id, TO_CHAR(last_post_at, 'YYYY-MM-DD')
      FROM topics WHERE category_id IN (SELECT id FROM categories WHERE archived)
     ORDER BY last_post_at DESC NULLS LAST"))

(defun sitemap-xml ()
  ;; статические + блог + категории + архивные темы; живой форум
  ;; индексируем через категории, отдельные страницы тем тоже отдаём
  (let* ((static '("/" "/blog" "/forum"))
         (rows (append
                (mapcar (lambda (p) (list p nil)) static)
                (seo/blog-sitemap-rows)
                (seo/category-sitemap-rows)
                (seo/topic-sitemap-rows))))
    (with-output-to-string (s)
      (format s "<?xml version=\"1.0\" encoding=\"UTF-8\"?>~%")
      (format s "<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">~%")
      (dolist (r rows)
        (destructuring-bind (path &optional lastmod) r
          (format s "  <url><loc>~A~A</loc>~@[<lastmod>~A</lastmod>~]</url>~%"
                  (site-url)
                  (cl-ppcre:regex-replace-all "&" path "&amp;")
                  lastmod)))
      (format s "</urlset>~%"))))

;;; --- RSS ----------------------------------------------------------------

(defun seo/rss-rows ()
  (postmodern:query
   "SELECT b.title,
           '/blog/' || u.username || '/' || b.slug,
           COALESCE(b.old_author, u.username),
           TO_CHAR(b.created_at, 'Dy, DD Mon YYYY HH24:MI:SS \"+0000\"')
      FROM blog_posts b JOIN users u ON u.id = b.user_id
     ORDER BY b.created_at DESC LIMIT 50"))

(defun rss-feed ()
  (with-output-to-string (s)
    (format s "<?xml version=\"1.0\" encoding=\"UTF-8\"?>~%")
    (format s "<rss version=\"2.0\"><channel>~%")
    (format s "<title>lisper — блог</title>~%")
    (format s "<link>~A/blog</link>~%" (site-url))
    (format s "<description>Common Lisp: статьи, wiki и архив старого lisper.ru</description>~%")
    (format s "<language>ru</language>~%")
    (dolist (r (seo/rss-rows))
      (destructuring-bind (title path author pubdate) r
        (format s "<item><title>~A</title><link>~A~A</link>~@[<author>~A</author>~]<pubDate>~A</pubDate></item>~%"
                (cl-ppcre:regex-replace-all "&" title "&amp;")
                (site-url) path author pubdate)))
    (format s "</channel></rss>~%")))

;;; --- JSON-LD -------------------------------------------------------------

(defun jsonld-blog-post (post username)
  "BlogPosting для страницы поста блога. POST — plist из get-blog-post-by-slug."
  (let* ((title (json-escape (getf post :title)))
         (iso (dmy-to-iso (getf post :created-at)))
         (url (format nil "~A/blog/~A/~A"
                      (site-url) username (getf post :slug)))
         (author (json-escape (or (getf post :old-author)
                                  username))))
    (format nil "{\"@context\":\"https://schema.org\",\"@type\":\"BlogPosting\",\"mainEntityOfPage\":{\"@type\":\"WebPage\",\"@id\":\"~A\"},\"headline\":\"~A\"~@[,\"datePublished\":\"~A\"~],\"author\":{\"@type\":\"Person\",\"name\":\"~A\"}}"
            url title iso author)))

(defun seo/description (text &optional (cap 160))
  "Мета-description: плоский текст, обрезанный по границе ~слова."
  (when text
    (let ((txt (string-trim " " (strip-html text))))
      (if (> (length txt) cap)
          (concatenate 'string
                       (string-trim " " (subseq txt 0 cap))
                       "…")
          txt))))

(defun seo/lang-alternates (base-path)
  "alist (lang . путь) для hreflang на индексных страницах."
  (loop for lang in *languages*
        collect (cons lang base-path)))

(defun jsonld-topic-posting (topic first-post)
  "DiscussionForumPosting для темы форума.
   TOPIC — plist из get-topic, FIRST-POST — СТРОКА из get-posts
   (id body created-at username role old-author), не plist!"
  (when topic
    (let* ((title (json-escape (getf topic :title)))
           (url (format nil "~A/topic/~D" (site-url) (getf topic :id)))
           (iso (dmy-to-iso (third first-post)))
           (author (json-escape (or (sql-null->nil (sixth first-post))
                                    (fourth first-post)
                                    "oldlisper"))))
      (format nil "{\"@context\":\"https://schema.org\",\"@type\":\"DiscussionForumPosting\",\"mainEntityOfPage\":{\"@type\":\"WebPage\",\"@id\":\"~A\"},\"headline\":\"~A\"~@[,\"datePublished\":\"~A\"~],\"author\":{\"@type\":\"Person\",\"name\":\"~A\"}}"
              url title iso author))))
