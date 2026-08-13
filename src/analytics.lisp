(in-package :lisper)

;;; Server-side analytics: page views, referrers, user agents, geo, unique visitors.
;;; Data in PostgreSQL (page_views); geo via in-memory MaxMind DB (cl-maxminddb).

(defparameter *analytics-bot-markers*
  '("googlebot" "bingbot" "slurp" "duckduckbot" "yandex" "baiduspider"
    "ia_archiver" "mj12bot" "ahrefs" "semrush" "dotbot" "sistrix"
    "spider" "crawler" "bot" "curl" "wget" "python-requests" "python-urllib"
    "facebookexternalhit" "twitterbot" "telegrambot" "archive.org_bot"
    "monitoring" "uptime"))

(defun request-header (env name)
  "Get a request header by lowercase name (Clack stores headers as a hash-table)."
  (let ((headers (getf env :headers)))
    (when headers
      (gethash name headers))))

(defun request-header-anycase (env name)
  "Get a header case-insensitively (Clack key casing may vary)."
  (let ((headers (getf env :headers)))
    (when headers
      (loop for k being the hash-keys of headers
            for v being the hash-values of headers
            when (string-equal k name)
              return v))))

(defun request-ip (env)
  "Client IP. Honor X-Real-IP / X-Forwarded-For (first hop) when present,
   else Clack :remote-addr. NOTE: the Wookie handler does not populate
   :remote-addr, so behind a proxy the IP comes only from the forwarding headers;
   otherwise it stays NULL in page_views."
  (or (let ((real (request-header env "x-real-ip")))
        (and real (plusp (length real)) (string-trim " " real)))
      (let ((forwarded (request-header env "x-forwarded-for")))
        (and forwarded (plusp (length forwarded))
             (string-trim " " (first (split-sequence:split-sequence #\, forwarded)))))
      (getf env :remote-addr)))

(defun request-referrer (env)
  (request-header-anycase env "referer"))

(defun request-user-agent (env)
  (request-header-anycase env "user-agent"))

(defun bot-user-agent-p (ua)
  "Deterministic boolean: T for known bot markers. `some' returns the match
   POSITION (e.g. 0), which postmodern would store as SQL false — force T/NIL."
  (when ua
    (if (some (lambda (marker) (search marker (string-downcase ua)))
              *analytics-bot-markers*)
        t
        nil)))

;;; --- Visitor identity ---

(defun parse-cookie-header (cookie-header)
  "Parse a Cookie header into a hash-table (name -> value). Nil safe."
  (let ((result (make-hash-table :test #'equal)))
    (when cookie-header
      (dolist (cookie (split-sequence:split-sequence #\; cookie-header))
        (let* ((parts (split-sequence:split-sequence #\= cookie))
               (key (string-trim " " (first parts)))
               (val (string-trim " " (or (second parts) ""))))
          (when (plusp (length key))
            (setf (gethash key result) val)))))
    result))

(defun sha256-hex (string)
  (ironclad:byte-array-to-hex-string
   (ironclad:digest-sequence
    :sha256
    (ironclad:ascii-string-to-byte-array string))))

(defun random-hex (nbytes)
  (ironclad:byte-array-to-hex-string (ironclad:random-data nbytes)))

(defun visitor-identity (env)
  "Return (values visitor-id set-cookie).
   visitor-id is a 32-hex hash stored in page_views. If the client has no
   'vid' cookie yet, generate one and return a Set-Cookie header for it."
  (let* ((table (parse-cookie-header (request-header env "cookie")))
         (vid (gethash "vid" table)))
    (if (and vid (plusp (length vid)))
        (values (subseq (sha256-hex vid) 0 32) nil)
        (let ((new (random-hex 16)))
          (values (subseq (sha256-hex new) 0 32)
                  (format nil "vid=~A; Path=/; Max-Age=31536000; HttpOnly" new))))))

;;; --- Geo (MaxMind DB via cl-maxminddb) ---

(defvar *geo-mmdb* nil
  "Mapped GeoLite2 database object from cl-maxminddb (make-mmdb), or NIL.")

(defun init-geo (path)
  "Open a GeoLite2 .mmdb file for country lookups. Path comes from config
   :geo-db-path. Missing file is not fatal — country lookups just return NIL."
  (setf *geo-mmdb* nil)
  (when (and path (probe-file path))
    (handler-case
        (progn
          (setf *geo-mmdb* (cl-maxminddb:make-mmdb (namestring (probe-file path))))
          (format t "~&Geo: loaded MaxMind DB from ~A~%" path))
      (error (e)
        (setf *geo-mmdb* nil)
        (format t "~&Warning: failed to load MaxMind DB ~A: ~A~%" path e))))
  *geo-mmdb*)

(defun country-for-ip (ip)
  "Look up the English country name for an IP from the mapped MaxMind DB.
   Returns NIL when the DB is not loaded or the IP is not in the database
   (a normal miss, e.g. private/local addresses)."
  (when (and *geo-mmdb* ip)
    (handler-case
        (let ((record (cl-maxminddb:mmdb-query *geo-mmdb* ip)))
          (or (cl-maxminddb:get-in record :country :names :en)
              (cl-maxminddb:get-in record :registered-country :names :en)
              (cl-maxminddb:get-in record :country :iso-code)))
      (error (e)
        (unless (search "not in the database" (princ-to-string e))
          (format t "~&Analytics mmdb lookup failed for ~A: ~A~%" ip e))
        nil))))

;;; --- Page view logging ---

(defun analytics-tracked-path-p (path)
  "True when a path is a page worth tracking (not CSS/JS/assets/downloads/admin)."
  (or (member path '("/" "/forum" "/new-topic" "/login" "/register")
              :test #'string=)
      (and (>= (length path) 7) (string= (subseq path 0 7) "/forum/"))
      (and (>= (length path) 7) (string= (subseq path 0 7) "/topic/"))
      (and (>= (length path) 6) (string= (subseq path 0 6) "/user/"))))

(defun sql-null-if-nil (v)
  "Postmodern converts Lisp NIL into the SQL string 'false'. For nullable text
   columns we want SQL NULL, which is passed via the :null keyword."
  (if v v :null))

(defun log-page-view (env path)
  "Insert one row into page_views. Returns Set-Cookie for a new 'vid' cookie, or nil."
  (unless *db-available*
    (return-from log-page-view nil))
  (multiple-value-bind (vid set-cookie) (visitor-identity env)
    (let* ((ua (request-user-agent env))
           (ip (request-ip env)))
      (postmodern:execute
       "INSERT INTO page_views (visitor_id, path, referrer, user_agent, ip, country, is_bot, lang)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)"
       vid path (sql-null-if-nil (request-referrer env)) ua
       (sql-null-if-nil ip)
       (sql-null-if-nil (country-for-ip ip))
       (bot-user-agent-p ua)
       (sql-null-if-nil *lang*))
      set-cookie)))

(defun maybe-track-analytics (env path response)
  "Given a page response, log a page view and attach a Set-Cookie header if needed."
  (handler-case
      (destructuring-bind (status headers body) response
        (if (and (eq (getf env :request-method) :GET)
                 (analytics-tracked-path-p path)
                 (= status 200))
            (let ((cookie (log-page-view env path)))
              (if cookie
                  (list status (append headers (list :set-cookie cookie)) body)
                  response))
            response))
    (error (e)
      (format t "~&Analytics error: ~A~%" e)
      response)))

;;; --- Aggregations for the admin dashboard ---
;;; Bounded retention: raw page_views live *analytics-raw-retention-days*,
;;; older rows are rolled up into daily_stats and deleted. Dashboard windows
;;; (24h/7d) read raw page_views; all-time totals read daily_stats + raw.

(defparameter *analytics-raw-retention-days* 7
  "Сколько дней сырые page_views хранятся до свёртки в daily_stats (окно дашборда).")

;;; Фильтр «люди / только боты»: :all / :people / :bots
(defun analytics-bot-and (bot-filter)
  "AND-fragment for queries that already have a WHERE clause."
  (case bot-filter
    (:people " AND is_bot = FALSE")
    (:bots " AND is_bot = TRUE")
    (otherwise "")))

(defun analytics-bot-where (bot-filter)
  "WHERE-fragment for queries without an existing WHERE clause."
  (case bot-filter
    (:people " WHERE is_bot = FALSE")
    (:bots " WHERE is_bot = TRUE")
    (otherwise "")))

(defun analytics-parse-tab (query-string)
  "Parse the dashboard ?tab=all|people|bots filter into a bot-filter keyword."
  (let* ((pairs (when query-string (split-sequence:split-sequence #\& query-string)))
         (tab (loop for pair in pairs
                    for parts = (split-sequence:split-sequence #\= pair)
                    when (string= (url-decode (first parts)) "tab")
                      return (string-downcase (url-decode (or (second parts) ""))))))
    (cond ((null tab) :all)
          ((string= tab "people") :people)
          ((string= tab "bots") :bots)
          (t :all))))

(defun analytics-strip-port (host)
  (let ((i (position #\: host)))
    (if i (subseq host 0 i) host)))

(defun analytics-internal-referrer-clause (own-hosts)
  "SQL AND-clause dropping internal/empty referrers from the sources report.
   own-hosts is one host name or a list (own domain names, e.g. the request Host
   header). Always also excludes localhost/loopback. Hosts are escaped before
   interpolation (Host header is attacker-influenced input)."
  (let* ((base (list "localhost" "127.0.0.1" "::1"))
         (extra (when own-hosts
                  (mapcar (lambda (h)
                            (let* ((h (string-downcase (string-trim " " h)))
                                   (h (analytics-strip-port h)))
                              (if (and (>= (length h) 4)
                                       (string= h "www." :start1 0 :end1 4))
                                  (subseq h 4)
                                  h)))
                          (if (listp own-hosts) own-hosts (list own-hosts)))))
         (hosts (remove-duplicates
                 (remove-if (lambda (h) (zerop (length h))) (append base extra))
                 :test #'string=)))
    (when hosts
      (format nil
              " AND (substring(referrer FROM 'https?://([^/]+)') IS NOT NULL AND regexp_replace(lower(split_part(substring(referrer FROM 'https?://([^/]+)'), ':', 1)), '^www\.', '') NOT IN (~{~A~^,~}))"
              (mapcar (lambda (h)
                        (concatenate 'string "'"
                                     (string-replace-all "'" "''" h) "'"))
                      hosts)))))

(defun analytics-total-views (bot-filter)
  (+ (or (postmodern:query
          (concatenate 'string "SELECT COUNT(*) FROM page_views"
                       (analytics-bot-where bot-filter))
          :single)
         0)
     (or (postmodern:query
          (concatenate 'string "SELECT COALESCE(SUM(views), 0) FROM daily_stats"
                       (analytics-bot-where bot-filter))
          :single)
         0)))

(defun analytics-run-rollup ()
  "One pass: aggregate page_views older than the retention window into
   daily_stats and delete the rolled-up raw rows. Idempotent (ON CONFLICT
   DO NOTHING), DB-safe (no-op when the database is unavailable)."
  (unless *db-available*
    (return-from analytics-run-rollup))
  (handler-case
      (let ((window (format nil "~A days" *analytics-raw-retention-days*)))
        (postmodern:query
         (concatenate 'string
                      "INSERT INTO daily_stats (date, path, country, device, browser, os, referrer, is_bot, views)
                       SELECT (created_at AT TIME ZONE 'UTC')::date, path,
                              COALESCE(country, 'Неизвестно'),
                              CASE WHEN user_agent ~* '(mobile|android|iphone|ipad|phone|blackberry)'
                                   THEN 'Мобильные' ELSE 'Десктоп' END,"
                      (analytics-browser-case)
                      ","
                      (analytics-os-case)
                      ", COALESCE(referrer, ''),
                              is_bot, COUNT(*)
                       FROM page_views
                       WHERE created_at < NOW() - $1::INTERVAL
                       GROUP BY 1, 2, 3, 4, 5, 6, 7, 8
                       ON CONFLICT (date, path, country, device, browser, os, referrer, is_bot) DO NOTHING"
                      )
         window)
        (postmodern:query
         "DELETE FROM page_views WHERE created_at < NOW() - $1::INTERVAL"
         window))
    (error (e)
      (format t "~&Analytics rollup error: ~A~%" e))))

(defun analytics-rollup-loop ()
  "Background thread body: roll up old page_views once a day."
  (loop (sleep 86400) (analytics-run-rollup)))

(defun analytics-views-since (bot-filter hours)
  (or (postmodern:query
       (concatenate 'string
                    "SELECT COUNT(*) FROM page_views WHERE created_at >= NOW() - $1::INTERVAL"
                    (analytics-bot-and bot-filter))
       (format nil "~A hours" hours) :single)
      0))

(defun analytics-unique-since (bot-filter hours)
  (or (postmodern:query
       (concatenate 'string
                    "SELECT COUNT(DISTINCT visitor_id) FROM page_views WHERE created_at >= NOW() - $1::INTERVAL"
                    (analytics-bot-and bot-filter))
       (format nil "~A hours" hours) :single)
      0))

(defun analytics-bot-count-since (hours)
  (or (postmodern:query
       "SELECT COUNT(*) FROM page_views WHERE is_bot AND created_at >= NOW() - $1::INTERVAL"
       (format nil "~A hours" hours) :single)
      0))

(defun analytics-people-unique-since (hours)
  "Unique non-bot visitors in the window — the users actually worth understanding."
  (or (postmodern:query
       "SELECT COUNT(DISTINCT visitor_id) FROM page_views
        WHERE NOT is_bot AND created_at >= NOW() - $1::INTERVAL"
       (format nil "~A hours" hours) :single)
      0))

(defun analytics-people-share-since (hours)
  "Share (percent) of page views in the window that are NOT bots."
  (let ((total (analytics-views-since :all hours))
        (people (analytics-views-since :people hours)))
    (if (plusp total) (round (* 100.0 (/ people total))) 0)))

(defun analytics-top-paths (bot-filter &optional (hours 0) (limit 10))
  (if (and hours (plusp hours))
      (postmodern:query
       (concatenate 'string
                    "SELECT path, COUNT(*) AS c FROM page_views
                     WHERE created_at >= NOW() - $1::INTERVAL"
                    (analytics-bot-and bot-filter)
                    " GROUP BY path ORDER BY c DESC LIMIT $2")
       (format nil "~A hours" hours) limit)
      (postmodern:query
       (concatenate 'string
                    "SELECT path, COUNT(*) AS c FROM page_views"
                    (analytics-bot-where bot-filter)
                    " GROUP BY path ORDER BY c DESC LIMIT $1")
       limit)))

(defun analytics-top-referrers (bot-filter own-hosts &optional (hours 0) (limit 10))
  "Top external sources: referrer reduced to its host, own/internal hosts excluded."
  (let ((excl (analytics-internal-referrer-clause own-hosts)))
    (if (and hours (plusp hours))
        (postmodern:query
         (concatenate 'string
                      "SELECT regexp_replace(lower(split_part(substring(referrer FROM 'https?://([^/]+)'), ':', 1)), '^www\.', '') AS host, COUNT(*) AS c
                       FROM page_views
                       WHERE referrer IS NOT NULL AND referrer <> ''
                         AND created_at >= NOW() - $1::INTERVAL"
                      (analytics-bot-and bot-filter)
                      excl
                      " GROUP BY host ORDER BY c DESC LIMIT $2")
         (format nil "~A hours" hours) limit)
        (postmodern:query
         (concatenate 'string
                      "SELECT regexp_replace(lower(split_part(substring(referrer FROM 'https?://([^/]+)'), ':', 1)), '^www\.', '') AS host, COUNT(*) AS c
                       FROM page_views
                       WHERE referrer IS NOT NULL AND referrer <> ''"
                      (analytics-bot-and bot-filter)
                      excl
                      " GROUP BY host ORDER BY c DESC LIMIT $1")
         limit))))

(defun analytics-top-countries (bot-filter &optional (hours 0) (limit 10))
  (let ((rows (if (and hours (plusp hours))
                  (postmodern:query
                   (concatenate 'string
                                "SELECT COALESCE(country, 'Неизвестно') AS country, COUNT(*) AS c FROM page_views
                                 WHERE created_at >= NOW() - $1::INTERVAL"
                                (analytics-bot-and bot-filter)
                                " GROUP BY country ORDER BY c DESC LIMIT $2")
                   (format nil "~A hours" hours) limit)
                  (postmodern:query
                   (concatenate 'string
                                "SELECT COALESCE(country, 'Неизвестно') AS country, COUNT(*) AS c FROM page_views"
                                (analytics-bot-where bot-filter)
                                " GROUP BY country ORDER BY c DESC LIMIT $1")
                   limit))))
    rows))

(defun analytics-top-devices (bot-filter &optional (hours 0) (limit 4))
  (if (and hours (plusp hours))
      (postmodern:query
       (concatenate 'string
                    "SELECT CASE WHEN user_agent ~* '(mobile|android|iphone|ipad|phone|blackberry)'
                                 THEN 'Мобильные' ELSE 'Десктоп' END AS device, COUNT(*) AS c
                     FROM page_views WHERE created_at >= NOW() - $1::INTERVAL"
                    (analytics-bot-and bot-filter)
                    " GROUP BY device ORDER BY c DESC LIMIT $2")
       (format nil "~A hours" hours) limit)
      (postmodern:query
       (concatenate 'string
                    "SELECT CASE WHEN user_agent ~* '(mobile|android|iphone|ipad|phone|blackberry)'
                                 THEN 'Мобильные' ELSE 'Десктоп' END AS device, COUNT(*) AS c
                     FROM page_views"
                    (analytics-bot-where bot-filter)
                    " GROUP BY device ORDER BY c DESC LIMIT $1")
       limit)))

;;; Browser/OS breakdown from user_agent. Canonical English labels are stored in
;;; daily_stats (survives the 7-day rollup); 'Другое' is translated at render.
(defun analytics-browser-case ()
  "SQL CASE expression mapping user_agent to a browser family label.
   Order matters: Edge/Opera (Chromium, contain 'chrome') and Android browsers
   must be matched before plain Chrome/Safari."
  "CASE
      WHEN user_agent ~* '(edg|msie|trident)' THEN 'Edge/IE'
      WHEN user_agent ~* '(opr/|opera)' THEN 'Opera'
      WHEN user_agent ~* '(chrome|crios)' THEN 'Chrome'
      WHEN user_agent ~* '(firefox|fxios)' THEN 'Firefox'
      WHEN user_agent ~* 'safari' THEN 'Safari'
      ELSE 'Другое' END")

(defun analytics-os-case ()
  "SQL CASE expression mapping user_agent to an OS family label.
   Order matters: Android UA contains 'linux', iOS UA contains 'mac os'."
  "CASE
      WHEN user_agent ~* 'windows' THEN 'Windows'
      WHEN user_agent ~* 'android' THEN 'Android'
      WHEN user_agent ~* '(iphone|ipad|ipod)' THEN 'iOS'
      WHEN user_agent ~* '(mac os|macintosh)' THEN 'macOS'
      WHEN user_agent ~* 'linux' THEN 'Linux'
      ELSE 'Другое' END")

(defun analytics-ua-breakdown (bot-filter case-sql agg-column &optional (limit 6))
  "All-time UA breakdown: UNION of the raw page_views buffer (7d) and the
   daily_stats rollup (older history), so the result survives retention."
  (postmodern:query
   (concatenate 'string
                "SELECT label, SUM(c) AS total FROM ("
                " SELECT " case-sql " AS label, COUNT(*) AS c FROM page_views"
                (analytics-bot-where bot-filter)
                " GROUP BY label"
                " UNION ALL"
                " SELECT " agg-column " AS label, views AS c FROM daily_stats"
                (analytics-bot-where bot-filter)
                ") u GROUP BY label ORDER BY total DESC LIMIT $1")
   limit))

(defun analytics-top-browsers (bot-filter &optional (limit 6))
  "All-time browser family breakdown across the raw buffer + daily_stats rollup."
  (analytics-ua-breakdown bot-filter (analytics-browser-case) "browser" limit))

(defun analytics-top-os (bot-filter &optional (limit 6))
  "All-time OS family breakdown across the raw buffer + daily_stats rollup."
  (analytics-ua-breakdown bot-filter (analytics-os-case) "os" limit))

(defun analytics-top-langs (bot-filter &optional (limit 10))
  "Views per served UI language (only raw page_views — the ~7-day buffer)."
  (postmodern:query
   (concatenate 'string
                "SELECT COALESCE(lang, '?') AS lang, COUNT(*) AS c FROM page_views"
                (analytics-bot-where bot-filter)
                " GROUP BY lang ORDER BY c DESC LIMIT $1")
   limit))

(defun analytics-daily-trend (bot-filter &optional (days 30))
  "Views per day for the last DAYS days. Combines the raw page_views buffer with
   the older daily_stats rollup (no overlap thanks to the retention window) and
   fills gap days with 0. Returns ((label views) ...), label is 'DD.MM'."
  (let* ((and-clause (analytics-bot-and bot-filter))
         (sql (concatenate 'string
               "SELECT TO_CHAR(d, 'DD.MM') AS day, COALESCE(v.views, 0) AS views
                FROM generate_series(CURRENT_DATE - $1::int, CURRENT_DATE, '1 day') d
                LEFT JOIN (
                  SELECT day, SUM(views) AS views FROM (
                    SELECT (created_at AT TIME ZONE 'UTC')::date AS day, COUNT(*) AS views
                    FROM page_views WHERE created_at >= CURRENT_DATE - $1::int"
               and-clause
               " GROUP BY day
                    UNION ALL
                    SELECT date AS day, views FROM daily_stats WHERE date >= CURRENT_DATE - $1::int"
               and-clause
               " ) u GROUP BY day
                ) v ON v.day = d::date
                ORDER BY d")))
    (postmodern:query sql (1- days))))

(defun analytics-recent (bot-filter &optional (limit 30))
  "Last visits. COALESCE the nullable columns so the renderer never sees
   postmodern's :NULL marker (which is truthy and breaks (or x \"\") / length)."
  (postmodern:query
   (concatenate 'string
                "SELECT path, COALESCE(referrer, ''), COALESCE(ip, ''),
                        COALESCE(country, ''), is_bot, COALESCE(user_agent, ''),
                        TO_CHAR(created_at, 'DD.MM HH24:MI')
                 FROM page_views"
                (analytics-bot-where bot-filter)
                " ORDER BY id DESC LIMIT $1")
   limit))

(defun analytics-geo-loaded-p ()
  "True when a MaxMind DB is mapped for country lookups."
  (and *geo-mmdb* t))