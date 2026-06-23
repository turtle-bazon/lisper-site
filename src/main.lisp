(in-package :lisper)

(defun main (&optional args)
  (declare (ignore args))
  (read-config)
  (db-connect)
  (format t "Starting lisper.ru on ~a:~a~%" (config :address) (config :port))
  (let ((server (clack:clackup (make-app)
                                :address (config :address)
                                :port (config :port)
                                :server :wookie
                                :debug nil)))
    (declare (ignore server))
    (loop (sleep 1))))
