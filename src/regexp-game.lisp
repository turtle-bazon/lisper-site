(in-package :lisper)

;;; /regexp-game — проверка регулярки игроком против фиксированных сэмплов.
;;; POST, raw body = регулярка (plain text, UTF-8).
;;; Требуется заголовок Authorization: Bearer <token>.
;;; Ответ JSON: {"right": N, "wrong": M, "solved": bool}
;;;   - right  = сколько right-сэмплов ПОЛНОСТЬЮ матчится регуляркой
;;;   - wrong  = сколько wrong-сэмплов ПОЛНОСТЬЮ матчится регуляркой
;;;   - solved = (right == (length right-samples)) и (wrong == 0)

(defparameter *regexp-game-token*
  "regexp-game-test-token-01")

;;; СЭМПЛЫ ДЛЯ ТЕСТОВ — заменить на реальные, когда пользователь их даст.
;;; right = строки, которые ПРАВИЛЬНАЯ регулярка должна принимать целиком.
;;; wrong = строки, которые правильная регулярка должна отклонять целиком.
(defparameter *regexp-game-right-samples*
  '("a" "b" "ab" "baa" "baba"))

(defparameter *regexp-game-wrong-samples*
  '("c" "x" "" "ab " "abc"))

(defun read-raw-body-text (env)
  "Прочитать raw request body как UTF-8 текст (без form-декодирования)."
  (let ((stream (getf env :raw-body)))
    (when stream
      (let ((buf (make-array 4096 :element-type '(unsigned-byte 8) :fill-pointer 0)))
        (loop for byte = (read-byte stream nil nil)
              while byte
              do (vector-push-extend byte buf))
        (flexi-streams:octets-to-string buf :external-format :utf-8)))))

(defun bearer-token (env)
  "Из Authorization-заголовка вытащить токен после 'Bearer '. NIL если нет."
  (let ((auth (request-header-anycase env "authorization")))
    (when auth
      (multiple-value-bind (m reg)
          (cl-ppcre:scan-to-strings "(?i)^Bearer\\s+(.+)$" (string-trim " " auth))
        (declare (ignore m))
        (when reg (aref reg 0))))))

(defun regexp-game-authorized-p (env)
  (and *regexp-game-token*
       (string= (bearer-token env) *regexp-game-token*)))

(defun regexp-full-match-p (regexp sample)
  "T если regexp матчит ВСЮ строку sample (а не только подстроку)."
  (multiple-value-bind (start end)
      (cl-ppcre:scan (format nil "\\A(?:~A)\\Z" regexp) sample)
    (and start (zerop start) (= end (length sample)))))

(defun regexp-sample-counts (regexp)
  "Сколько right- и wrong-сэмплов полностью матчится регуляркой."
  (values (count-if (lambda (s) (regexp-full-match-p regexp s))
                    *regexp-game-right-samples*)
          (count-if (lambda (s) (regexp-full-match-p regexp s))
                    *regexp-game-wrong-samples*)))

(defun regexp-game-json (right wrong)
  "Ответ-объект: right/wrong/solved."
  (format nil "{\"right\": ~D, \"wrong\": ~D, \"solved\": ~:[false~;true~]}"
          right wrong
          (and (= right (length *regexp-game-right-samples*))
               (zerop wrong))))

(defun handle-regexp-game (env)
  (if (not (regexp-game-authorized-p env))
      `(401 (:content-type "application/json; charset=utf-8")
            ("{\"error\": \"unauthorized\"}"))
      (let ((regexp (string-trim '(#\Space #\Tab #\Newline)
                                 (or (read-raw-body-text env) ""))))
        (if (zerop (length regexp))
            `(400 (:content-type "application/json; charset=utf-8")
                  ("{\"error\": \"empty regexp\"}"))
            (handler-case
                (multiple-value-bind (right wrong)
                    (regexp-sample-counts regexp)
                  `(200 (:content-type "application/json; charset=utf-8")
                        (,(regexp-game-json right wrong))))
              (error (e)
                (format t "~&Regexp-game: невалидная регулярка ~S: ~A~%"
                        regexp e)
                `(400 (:content-type "application/json; charset=utf-8")
                      ("{\"error\": \"invalid regexp\"}"))))))))