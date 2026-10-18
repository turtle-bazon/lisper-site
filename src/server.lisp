;;; Запуск веб-сервера. Выделено из main, чтобы CLI (cli.lisp) мог
;;; использовать start-server без циклических ссылок между файлами.

(in-package :lisper)

(defun start-server ()
  ;; Невалидный конфиг = фатально. read-config уже напечатал перечень
  ;; проблем (config-report-errors), здесь — НЕ пускать в дебаггер SBCL:
  ;; он печатает backtrace и выходит с кодом 0, а quadlet/systemd по коду 0
  ;; решили бы, что сервер «поработал и завершился», и не рестартанули.
  (handler-case (read-config)
    (error (e)
      (format t "~&~A~%" e)
      (uiop:quit 1)))
  (handler-case (db-connect)
    (error (e) (format t "~&Warning: DB connect failed: ~A~%" e)))
  (init-geo (config :geo-db-path))
  (analytics-run-rollup)
  (sb-thread:make-thread #'analytics-rollup-loop :name "analytics-rollup")
  (format t "Starting lisper on ~a:~a~%" (config :address) (config :port))
  ;; :debug t заставляет Wookie вызывать отладчик SBCL В КОНТЕКСТЕ ЗАПРОСА при
  ;; непойманной ошибке — запрос не завершается никогда, соединение висит, и
  ;; Cloudflare отдаёт 522 (origin connection timed out). В проде это ловилось
  ;; как ~5% неудачных запросов при быстром темпе. Поэтому флаг читается из
  ;; конфига и по умолчанию nil; :debug t — только для локальной отладки.
  (format t "lisper debug mode: ~a~%" (if (config :debug nil) "ON (errors will hang requests)" "off"))
  (let ((server (clack:clackup (make-app)
                                :address (config :address)
                                :port (config :port)
                                :server :wookie
                                :debug (config :debug nil))))
    (declare (ignore server))
    (loop (sleep 1))))
