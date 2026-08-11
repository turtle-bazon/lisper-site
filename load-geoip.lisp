;;; load-geoip.lisp — загрузка GeoLite2 Country CSV в таблицу ip_country
;;; Использование: make geo-load FILE=/path/to/GeoLite2-Country-CSV.csv
;;; Файл большой — загрузка батчами по 2000 диапазонов.

(defun position-after (sublist list)
  (let ((i (search sublist list :test #'string=)))
    (when i (+ i (length sublist)))))

(defun script-file-arg ()
  "Вернуть аргумент после '--' в командной строке sbcl, или nil."
  (let ((i (position-after '("--") sb-ext:*posix-argv*)))
    (when i (nth i sb-ext:*posix-argv*))))

(defun main (arg)
  (unless arg
    (format t "~&Usage: make geo-load FILE=/path/to/GeoLite2-Country-CSV.csv~%")
    (uiop:quit 1))
  (format t "~&Loading lisper...~%")
  (ql:quickload :lisper)
  (format t "~&Loading geo data from ~A...~%" arg)
  (lisper::load-ip-country-csv arg)
  (uiop:quit 0))

(main (script-file-arg))