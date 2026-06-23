(in-package :lisper)

(defun hash-password (password)
  (multiple-value-bind (key salt)
      (ironclad:pbkdf2-hash-password
       (ironclad:ascii-string-to-byte-array password)
       :digest :sha256
       :iterations 100000)
    (format nil "~A:~A"
            (ironclad:byte-array-to-hex-string salt)
            (ironclad:byte-array-to-hex-string key))))

(defun verify-password (password stored)
  (let* ((parts (split-sequence:split-sequence #\: stored))
         (salt (ironclad:hex-string-to-byte-array (first parts)))
         (expected (ironclad:hex-string-to-byte-array (second parts)))
         (key (ironclad:pbkdf2-hash-password
               (ironclad:ascii-string-to-byte-array password)
               :salt salt
               :digest :sha256
               :iterations 100000)))
    (equalp key expected)))

(defun register-user (username email password)
  (let ((hash (hash-password password)))
    (handler-case
        (progn
          (postmodern:execute
           "INSERT INTO users (username, email, password_hash) VALUES ($1, $2, $3)"
           username email hash)
          (let ((user-id (postmodern:query "SELECT currval('users_id_seq')" :single)))
            (create-user-session user-id)))
      (cl-postgres:database-error ()
        nil))))

(defun authenticate-user (email password)
  (let ((row (postmodern:query
              "SELECT id, password_hash FROM users WHERE email = $1"
              email)))
    (when row
      (let ((id (first (first row)))
            (hash (second (first row))))
        (when (verify-password password hash)
          (create-user-session id))))))

(defun create-user-session (user-id)
  (let ((token (ironclad:byte-array-to-hex-string
                (ironclad:random-data 32))))
    (postmodern:execute
     "INSERT INTO sessions (user_id, token, expires_at) VALUES ($1, $2, NOW() + INTERVAL '30 days')"
     user-id token)
    token))

(defun get-user-by-session (token)
  (when token
    (let ((row (postmodern:query
                "SELECT u.id, u.username, u.email, u.role
                 FROM users u
                 JOIN sessions s ON s.user_id = u.id
                 WHERE s.token = $1 AND s.expires_at > NOW()"
                token)))
      (when row
        (destructuring-bind (id username email role) (first row)
          (list :id id :username username :email email :role role))))))

(defun delete-session (token)
  (when token
    (postmodern:execute "DELETE FROM sessions WHERE token = $1" token)))

(defun session-user-id (user)
  (getf user :id))

(defun session-username (user)
  (getf user :username))

(defun session-role (user)
  (getf user :role))

(defun user-admin-p (user)
  (string= (session-role user) "admin"))

(defun user-moderator-p (user)
  (or (user-admin-p user)
      (string= (session-role user) "moderator")))

(defun extract-session-token (env)
  (let* ((headers (getf env :headers))
         (cookie-header (when headers (gethash "cookie" headers))))
    (when cookie-header
      (let ((cookies (split-sequence:split-sequence #\; cookie-header)))
        (loop for cookie in cookies
              for pair = (mapcar #'string-trim
                                 (list " " "")
                                 (split-sequence:split-sequence #\= cookie))
              when (string= (first pair) "session")
                return (second pair))))))

(defun current-user (env)
  (get-user-by-session (extract-session-token env)))
