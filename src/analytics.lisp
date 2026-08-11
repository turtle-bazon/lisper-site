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
       "INSERT INTO page_views (visitor_id, path, referrer, user_agent, ip, country, is_bot)
        VALUES ($1, $2, $3, $4, $5, $6, $7)"
       vid path (sql-null-if-nil (request-referrer env)) ua
       (sql-null-if-nil ip)
       (sql-null-if-nil (country-for-ip ip))
       (bot-user-agent-p ua))
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

(defun analytics-total-views ()
  (+ (or (postmodern:query "SELECT COUNT(*) FROM page_views" :single) 0)
     (or (postmodern:query
          "SELECT COALESCE(SUM(views), 0) FROM daily_stats" :single)
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
         "INSERT INTO daily_stats (date, path, country, device, referrer, is_bot, views)
          SELECT (created_at AT TIME ZONE 'UTC')::date, path,
                 COALESCE(country, 'Неизвестно'),
                 CASE WHEN user_agent ~* '(mobile|android|iphone|ipad|phone|blackberry)'
                      THEN 'Мобильные' ELSE 'Десктоп' END,
                 COALESCE(referrer, ''),
                 is_bot, COUNT(*)
          FROM page_views
          WHERE created_at < NOW() - $1::INTERVAL
          GROUP BY 1, 2, 3, 4, 5, 6
          ON CONFLICT (date, path, country, device, referrer, is_bot) DO NOTHING"
         window)
        (postmodern:query
         "DELETE FROM page_views WHERE created_at < NOW() - $1::INTERVAL"
         window))
    (error (e)
      (format t "~&Analytics rollup error: ~A~%" e))))

(defun analytics-rollup-loop ()
  "Background thread body: roll up old page_views once a day."
  (loop (sleep 86400) (analytics-run-rollup)))

(defun analytics-views-since (hours)
  (or (postmodern:query
       "SELECT COUNT(*) FROM page_views WHERE created_at >= NOW() - $1::INTERVAL"
       (format nil "~A hours" hours) :single)
      0))

(defun analytics-unique-since (hours)
  (or (postmodern:query
       "SELECT COUNT(DISTINCT visitor_id) FROM page_views WHERE created_at >= NOW() - $1::INTERVAL"
       (format nil "~A hours" hours) :single)
      0))

(defun analytics-bot-count-since (hours)
  (or (postmodern:query
       "SELECT COUNT(*) FROM page_views WHERE is_bot AND created_at >= NOW() - $1::INTERVAL"
       (format nil "~A hours" hours) :single)
      0))

(defun analytics-top-paths (&optional (hours 0) (limit 10))
  (if (and hours (plusp hours))
      (postmodern:query
       "SELECT path, COUNT(*) AS c FROM page_views
        WHERE created_at >= NOW() - $1::INTERVAL GROUP BY path ORDER BY c DESC LIMIT $2"
       (format nil "~A hours" hours) limit)
      (postmodern:query
       "SELECT path, COUNT(*) AS c FROM page_views GROUP BY path ORDER BY c DESC LIMIT $1"
       limit)))

(defun analytics-top-referrers (&optional (hours 0) (limit 10))
  (if (and hours (plusp hours))
      (postmodern:query
       "SELECT referrer, COUNT(*) AS c FROM page_views
        WHERE referrer IS NOT NULL AND referrer <> ''
          AND created_at >= NOW() - $1::INTERVAL
        GROUP BY referrer ORDER BY c DESC LIMIT $2"
       (format nil "~A hours" hours) limit)
      (postmodern:query
       "SELECT referrer, COUNT(*) AS c FROM page_views
        WHERE referrer IS NOT NULL AND referrer <> ''
        GROUP BY referrer ORDER BY c DESC LIMIT $1"
       limit)))

(defun analytics-top-countries (&optional (hours 0) (limit 10))
  (let ((rows (if (and hours (plusp hours))
                  (postmodern:query
                   "SELECT COALESCE(country, 'Неизвестно') AS country, COUNT(*) AS c FROM page_views
                    WHERE created_at >= NOW() - $1::INTERVAL GROUP BY country ORDER BY c DESC LIMIT $2"
                   (format nil "~A hours" hours) limit)
                  (postmodern:query
                   "SELECT COALESCE(country, 'Неизвестно') AS country, COUNT(*) AS c FROM page_views
                    GROUP BY country ORDER BY c DESC LIMIT $1"
                   limit))))
    rows))

(defun analytics-top-devices (&optional (hours 0) (limit 4))
  (if (and hours (plusp hours))
      (postmodern:query
       "SELECT CASE WHEN user_agent ~* '(mobile|android|iphone|ipad|phone|blackberry)'
                     THEN 'Мобильные' ELSE 'Десктоп' END AS device, COUNT(*) AS c
        FROM page_views WHERE created_at >= NOW() - $1::INTERVAL
        GROUP BY device ORDER BY c DESC LIMIT $2"
       (format nil "~A hours" hours) limit)
      (postmodern:query
       "SELECT CASE WHEN user_agent ~* '(mobile|android|iphone|ipad|phone|blackberry)'
                     THEN 'Мобильные' ELSE 'Десктоп' END AS device, COUNT(*) AS c
        FROM page_views GROUP BY device ORDER BY c DESC LIMIT $1"
       limit)))

(defun analytics-recent (&optional (limit 30))
  "Last visits. COALESCE the nullable columns so the renderer never sees
   postmodern's :NULL marker (which is truthy and breaks (or x \"\") / length)."
  (postmodern:query
   "SELECT path, COALESCE(referrer, ''), COALESCE(ip, ''),
           COALESCE(country, ''), is_bot, COALESCE(user_agent, ''),
           TO_CHAR(created_at, 'DD.MM HH24:MI')
    FROM page_views ORDER BY id DESC LIMIT $1"
   limit))

(defun analytics-geo-loaded-p ()
  "True when a MaxMind DB is mapped for country lookups."
  (and *geo-mmdb* t))