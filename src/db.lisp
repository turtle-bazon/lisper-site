(in-package :lisper)

(defvar *db-spec* nil
  "PostgreSQL connection spec: (database user password host &key port)")

;;; Migrations are embedded in src/migrations.lisp

(defun db-connect ()
  "Connect to PostgreSQL and run pending migrations."
  (let ((spec (list (config :db-name "lisper")
                    (config :db-user "lisper")
                    (config :db-password "lisper")
                    (config :db-host "127.0.0.1")
                    :port (or (config :db-port) 5432))))
    (setf *db-spec* spec)
    (apply #'postmodern:connect-toplevel spec)
    (postmodern:execute
     "CREATE TABLE IF NOT EXISTS schema_migrations (
        version INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        applied_at TIMESTAMP DEFAULT NOW()
      )")
    (run-pending-migrations)))

(defun db-disconnect ()
  (when (postmodern:connected-p)
    (postmodern:disconnect)))

(defun get-applied-migrations ()
  "Return sorted list of applied migration version numbers."
  (sort (mapcar #'first
                (postmodern:query "SELECT version FROM schema_migrations ORDER BY version"))
        #'<))

;;; get-available-migrations and get-migration-sql are in migrations.lisp

(defun read-migration-sql (version direction)
  "Get migration SQL from embedded data. direction is :up or :down."
  (get-migration-sql version direction))

(defun apply-migration (version name sql)
  "Apply a single migration - split by semicolons and execute each."
  (let ((stmts (split-sequence:split-sequence #\; sql)))
    (dolist (stmt stmts)
      (let ((trimmed (string-trim '(#\Space #\Tab #\Newline #\Return) stmt)))
        (when (plusp (length trimmed))
          (postmodern:query trimmed)))))
  (postmodern:query "INSERT INTO schema_migrations (version, name) VALUES ($1, $2)"
                    version name)
  (format t "~&Applied migration ~4,'0D: ~A~%" version name))

(defun run-pending-migrations ()
  "Apply all pending migrations in order."
  (let ((applied (get-applied-migrations))
        (available (get-available-migrations)))
    (dolist (entry available)
      (destructuring-bind (version name) entry
        (unless (member version applied)
              (let ((sql (read-migration-sql version :up)))
                (if sql
                    (apply-migration version name sql)
                    (format t "~&Warning: Migration SQL not found for ~4,'0D~%" version)))))))
  (format t "~&Migrations complete.~%"))

(defun rollback-last-migration ()
  "Rollback the most recently applied migration."
  (let ((applied (get-applied-migrations)))
    (if applied
        (let* ((version (car (last applied)))
               (entry (find version (get-available-migrations) :key #'first))
               (name (second entry))
               (sql (read-migration-sql version :down)))
          (if sql
              (progn
                (postmodern:with-transaction ()
                  (postmodern:execute sql)
                  (postmodern:execute
                   "DELETE FROM schema_migrations WHERE version = $1"
                   version))
                (format t "~&Rolled back migration ~4,'0D: ~A~%" version name))
              (format t "~&Warning: Rollback SQL not found for ~4,'0D~%" version)))
        (format t "~&No migrations to rollback.~%"))))

(defun rollback-n-migrations (n)
  "Rollback the last N migrations."
  (dotimes (i n)
    (rollback-last-migration)))

(defun current-migration-version ()
  "Return the current (latest applied) migration version, or 0 if none."
  (let ((applied (get-applied-migrations)))
    (if applied
        (car (last applied))
        0)))

(defun migration-status ()
  "Print status of all migrations."
  (let ((applied (get-applied-migrations))
        (available (get-available-migrations)))
    (format t "~&Migration Status:~%")
    (format t "Current version: ~A~%" (current-migration-version))
    (dolist (entry available)
      (destructuring-bind (version name) entry
        (format t "  ~4,'0D ~A [~A]~%"
                version name
                (if (member version applied) "applied" "pending"))))))
