(in-package :lisper)

(defvar *config* nil)

(defparameter *default-config*
  '(:address "0.0.0.0"
    :port 8080
    :log-level :info
    :db-host "127.0.0.1"
    :db-port 5432
    :db-name "lisper"
    :db-user "lisper"
    :db-password "lisper"))

(defun config-file-paths ()
  (list (probe-file "lisper.conf")
        (probe-file (merge-pathnames #p".lisper.conf" (user-homedir-pathname)))
        (probe-file (merge-pathnames #p".config/lisper/lisper.conf" (user-homedir-pathname)))
        (probe-file #p"/etc/lisper.conf")))

(defun read-config ()
  (let ((path (find-if #'identity (config-file-paths))))
    (if path
        (with-open-file (s path :direction :input)
          (setf *config* (read s)))
        (setf *config* *default-config*))))

(defun config (key &optional default)
  (or (getf *config* key) default))
