(in-package :lisper)

;;; Server-side analytics: page views, referrers, user agents, geo, unique visitors.
;;; Data in PostgreSQL (page_views, ip_country). Admin dashboard at /admin/analytics.

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

;;; --- Geo ---

(defun country-for-ip (ip)
  "Look up country name for an IP from the ip_country table (cidr ranges)."
  (when ip
    (handler-case
        (let ((row (postmodern:query
                    "SELECT country_name FROM ip_country WHERE network >>= $1::inet LIMIT 1"
                    ip)))
          (when row (first (first row))))
      (error (e) (format t "~&Analytics county lookup failed for ~A: ~A~%" ip e) nil))))

(defun flush-ip-batches (rows)
  (dolist (row rows)
    (destructuring-bind (network iso name) row
      (postmodern:query
       "INSERT INTO ip_country (network, country_code, country_name) VALUES ($1::cidr, $2, $3) ON CONFLICT DO NOTHING"
       network iso name))))

(defun load-ip-country-csv (path)
  "Load GeoLite2 Country CSV (GeoLite2-Country-CSV_*/GeoLite2-Country-CSV.csv)
   into the ip_country table. Batch insert for speed."
  (db-connect)
  (let ((count 0)
        (batch '()))
    (with-open-file (stream path :external-format :utf-8)
      (read-line stream) ; skip header
      (loop for line = (read-line stream nil nil)
            while line
            do (let* ((parts (split-sequence:split-sequence #\, line))
                      (network (nth 0 parts))
                      (iso (nth 6 parts))
                      (name (string-trim '(#\Space #\Tab #\Newline #\Return)
                                         (or (nth 7 parts) ""))))
                 (when (and network iso name
                            (not (string= iso ""))
                            (not (string= name "")))
                   (push (list network iso name) batch)
                   (incf count))
                 (when (>= (length batch) 2000)
                   (flush-ip-batches batch)
                   (setf batch '()))))
      (when batch
        (flush-ip-batches batch)))
    (postmodern:execute "ANALYZE ip_country")
    (format t "~&Loaded ~A IP ranges into ip_country~%" count)))

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

(defun analytics-total-views ()
  (or (postmodern:query "SELECT COUNT(*) FROM page_views" :single) 0))

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
  (postmodern:query
   "SELECT path, referrer, ip, country, is_bot, user_agent,
           TO_CHAR(created_at, 'DD.MM HH24:MI')
    FROM page_views ORDER BY id DESC LIMIT $1"
   limit))

(defun analytics-geo-loaded-p ()
  (plusp (or (postmodern:query "SELECT COUNT(*) FROM ip_country" :single) 0)))