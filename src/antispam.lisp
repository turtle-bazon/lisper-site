(in-package :lisper)

;;; Антиспам: rate limiting (in-memory sliding window) + подписанные
;;; таймстамп-токены для форм (HMAC-SHA256). Без внешних сервисов.

;;; ------------------------------------------------------------
;;; Rate limiting
;;; ------------------------------------------------------------

(defvar *rate-table* (make-hash-table :test 'equal)
  "key -> список universal-time штампов последних событий")

(defvar *rate-cleanup-counter* 0)

(defun rate-allowed-p (key limit window)
  "Sliding-window лимит: не более LIMIT событий за WINDOW секунд на KEY.
Возвращает T, если событие разрешено (и записывает его)."
  (let* ((now (get-universal-time))
         (cutoff (- now window))
         (stamps (delete-if (lambda (ts) (< ts cutoff))
                            (gethash key *rate-table* '()))))
    (if (>= (length stamps) limit)
        (progn
          (setf (gethash key *rate-table*) stamps)
          nil)
        (progn
          (setf (gethash key *rate-table*) (cons now stamps))
          t))))

(defun rate-cleanup ()
  "Удаляет устаревшие записи (старше суток), чтобы таблица не росла."
  (let ((cutoff (- (get-universal-time) 86400)))
    (maphash (lambda (k v)
               (let ((fresh (delete-if (lambda (ts) (< ts cutoff)) v)))
                 (if fresh
                     (setf (gethash k *rate-table*) fresh)
                     (remhash k *rate-table*))))
             *rate-table*)))

(defun rate-maybe-cleanup ()
  "Периодическая чистка: раз в ~1000 вызовов."
  (incf *rate-cleanup-counter*)
  (when (> *rate-cleanup-counter* 1000)
    (setf *rate-cleanup-counter* 0)
    (rate-cleanup)))

;;; ------------------------------------------------------------
;;; Подписанные токены форм (защита от слепых POST-ботов)
;;; ------------------------------------------------------------

(defun form-secret ()
  "Секрет для HMAC токенов форм."
  (or (config :form-secret)
      (config :admin-secret)
      "lisper-default-form-secret"))

(defun hmac-hex (message)
  (let* ((key (ironclad:ascii-string-to-byte-array (form-secret)))
         (hmac (ironclad:make-hmac key :sha256)))
    (ironclad:update-hmac hmac (ironclad:ascii-string-to-byte-array message))
    (ironclad:byte-array-to-hex-string (ironclad:hmac-digest hmac))))

(defun make-form-token ()
  "Токен вида \"<unix-ts>:<hmac>\" — вставляется в форму при рендере."
  (let ((ts (get-universal-time)))
    (format nil "~A:~A" ts (hmac-hex (write-to-string ts)))))

(defun verify-form-token (token &key (min-age 2) (max-age 86400))
  "Проверяет подпись и возраст токена: форма должна быть отправлена
не раньше MIN-AGE секунд после рендера (боты шлют мгновенно)
и не позже MAX-AGE (сутки — чтобы открытая вкладка не протухала)."
  (when token
    (let ((parts (split-sequence:split-sequence #\: token)))
      (when (= (length parts) 2)
        (let ((ts-str (first parts))
              (mac (second parts)))
          (let ((ts (ignore-errors (parse-integer ts-str))))
            (when ts
              (and (string= mac (hmac-hex ts-str))
                   (let ((age (- (get-universal-time) ts)))
                     (and (>= age min-age) (<= age max-age)))))))))))

;;; ------------------------------------------------------------
;;; Proof-of-work (hashcash): клиент ищет nonce, для которого
;;; SHA-256(salt ‖ nonce) имеет DIFF ведущих нулевых бит.
;;; Stateless: соль и сложность подписаны HMAC в токене формы.
;;; ------------------------------------------------------------

(defvar *pow-difficulty* 18
  "Ведущих нулевых бит. 18 ≈ 260k хешей (~0.3-1с в браузере).")

(defun leading-zero-bits (bytes)
  "Число ведущих нулевых бит дайджеста (до первого ненулевого байта)."
  (let ((bits 0))
    (loop for b across bytes
          do (cond ((= b 0) (incf bits 8))
                   (t
                    (loop for k from 7 downto 0
                          until (logbitp k b)
                          do (incf bits))
                    (return-from leading-zero-bits bits))))
    bits))

(defun make-pow-challenge ()
  "Токен вида \"ts:diff:salt:hmac(ts:diff:salt)\"."
  (let* ((ts (get-universal-time))
         (salt (ironclad:byte-array-to-hex-string
                (ironclad:random-data 12)))
         (diff *pow-difficulty*)
         (msg (format nil "~A:~A:~A" ts diff salt)))
    (format nil "~A:~A" msg (hmac-hex msg))))

(defun verify-pow (token nonce &key (max-age 3600))
  "Проверяет подпись challenge, возраст и что SHA-256(salt ‖ nonce)
даёт не меньше бит нулей, чем заявлено в токене."
  (when (and token nonce)
    (let ((parts (split-sequence:split-sequence #\: token)))
      (when (= (length parts) 4)
        (destructuring-bind (ts-str diff-str salt mac) parts
          (let ((ts (ignore-errors (parse-integer ts-str)))
                (diff (ignore-errors (parse-integer diff-str)))
                (n (ignore-errors (parse-integer nonce))))
            (when (and ts diff n (> diff 0) (<= diff 26))
              (and (string= mac (hmac-hex (format nil "~A:~A:~A" ts-str diff-str salt)))
                   (let ((age (- (get-universal-time) ts)))
                     (when (and (>= age 0) (<= age max-age))
                       (>= (leading-zero-bits
                            (ironclad:digest-sequence
                             :sha256
                             (concatenate '(vector (unsigned-byte 8))
                                          (ironclad:ascii-string-to-byte-array salt)
                                          (ironclad:ascii-string-to-byte-array
                                           (write-to-string n)))))
                           diff)))))))))))

;;; ------------------------------------------------------------
;;; Валидация полей регистрации
;;; ------------------------------------------------------------

(defun valid-username-p (s)
  (and (stringp s)
       (>= (length s) 3)
       (<= (length s) 20)
       (every (lambda (c) (or (alphanumericp c) (char= c #\_))) s)))

(defun valid-email-p (s)
  (and (stringp s)
       (<= 6 (length s) 254)
       (not (find #\space s))
       (let ((at (position #\@ s)))
         (when at
           (let ((domain (subseq s (+ at 1))))
             (and (> at 0)
                  (plusp (length domain))
                  (position #\. domain)
                  (not (char= (char s (1- (length s))) #\.))
                  (not (char= (char s (1- (length s))) #\@))))))))

(defun valid-password-p (s)
  (and (stringp s) (>= (length s) 8) (<= (length s) 128)))

;;; ------------------------------------------------------------
;;; CAPTCHA «анимированный шум» (как на AliExpress): 4 цифры,
;;; каждая мигает в своём слоте времени поверх мерцающего шума.
;;; Человек «досматривает» кадры глазами, скрапер видит только
;;; разметку с координатами штрихов (текста в HTML нет).
;;; Stateless: код спрятан в HMAC-токене.
;;; ------------------------------------------------------------

(defvar *captcha-dur* 2.4)      ; полный цикл анимации, сек
(defvar *captcha-slot* 0.6)     ; слот одной цифры, сек
(defvar *captcha-visible* 0.42) ; сколько секунд цифра видна в слоте

(defun seven-seg-lines ()
  "Координаты штрихов 7-сегментной ячейки 16x28: сегмент -> (x1 y1 x2 y2)."
  '((#\a . (2 1 14 1))
    (#\b . (15 2 15 13))
    (#\c . (15 15 15 26))
    (#\d . (2 27 14 27))
    (#\e . (1 15 1 26))
    (#\f . (1 2 1 13))
    (#\g . (2 14 14 14))))

(defun digit-segments (digit)
  (nth digit
       '((#\a #\b #\c #\d #\e #\f)          ; 0
         (#\b #\c)                              ; 1
         (#\a #\b #\g #\e #\d)               ; 2
         (#\a #\b #\g #\c #\d)               ; 3
         (#\f #\g #\b #\c)                    ; 4
         (#\a #\f #\g #\c #\d)               ; 5
         (#\a #\f #\g #\e #\d #\c)          ; 6
         (#\a #\b #\c)                         ; 7
         (#\a #\b #\c #\d #\e #\f #\g)     ; 8
         (#\a #\b #\c #\d #\f #\g))))       ; 9

(defun captcha-jitter ()
  "Случайный сдвиг координаты -1..+1: ломает парсинг разметки по
фиксированной карте сегментов (каждый запрос имеет свою геометрию)."
  (- (random 3) 1))

(defun captcha-digit-group (digit index stream)
  "Одна цифра: 7-сегментные штрихи со случайным джиттером, видны только
в своём временном слоте."
  (let* ((x (+ 12 (* index 36)))
         (rot (- (random 17) 8))
         (start (* index (/ *captcha-slot* *captcha-dur*)))
         (end (+ start (/ *captcha-visible* *captcha-dur*)))
         (sw (+ 3 (random 2))))
    (format stream "<g transform=\"translate(~d,10) rotate(~d 8 14)\">" x rot)
    (dolist (seg (digit-segments digit))
      (let ((l (cdr (assoc seg (seven-seg-lines)))))
        (format stream
                "<line x1=\"~d\" y1=\"~d\" x2=\"~d\" y2=\"~d\" stroke=\"#22c55e\" stroke-width=\"~d\" stroke-linecap=\"round\"><animate attributeName=\"opacity\" values=\"0;1;0\" keyTimes=\"0;~,3f;~,3f\" calcMode=\"discrete\" dur=\"~,1fs\" repeatCount=\"indefinite\"/></line>"
                (+ (first l) (captcha-jitter))
                (+ (second l) (captcha-jitter))
                (+ (third l) (captcha-jitter))
                (+ (fourth l) (captcha-jitter))
                sw start end *captcha-dur*)))
    (format stream "</g>")))

(defun captcha-noise (stream count)
  "Мерцающие прямоугольники шума со случайными фазами."
  (dotimes (i count)
    (let* ((x (random 156)) (y (random 44))
           (w (+ 2 (random 3))) (h (+ 2 (random 3)))
           (dur (/ (+ 25 (random 55)) 100))
           (begin (- (/ (random 80) 100)))
           (col (nth (random 4)
                     '("#1f2937" "#374151" "#4b5563" "#6b7280"))))
      (format stream
              "<rect x=\"~,0f\" y=\"~,0f\" width=\"~d\" height=\"~d\" fill=\"~a\"><animate attributeName=\"opacity\" values=\"0;1;0\" keyTimes=\"0;0.5;1\" dur=\"~,2fs\" begin=\"~,2fs\" repeatCount=\"indefinite\"/></rect>"
              x y w h col dur begin))))

(defun make-captcha ()
  "Возвращает cons (svg-строка . токен); токен = \"ts:hmac(ts:код)\"."
  (let* ((code (loop repeat 4 collect (random 10)))
         (code-str (format nil "~{~d~}" code))
         (ts (get-universal-time))
         (token (format nil "~A:~A" ts
                        (hmac-hex (format nil "~A:~A" ts code-str))))
         (svg (with-output-to-string (s)
                (format s "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"160\" height=\"48\" viewBox=\"0 0 160 48\" role=\"img\" aria-label=\"captcha\">")
                (format s "<rect width=\"160\" height=\"48\" rx=\"6\" fill=\"#0d1117\"/>")
                (captcha-noise s 110)
                (loop for d in code
                      for i from 0
                      do (captcha-digit-group d i s))
                (format s "</svg>"))))
    (cons svg token)))

(defun verify-captcha (token user-answer &key (max-age 86400))
  "Проверка: перподписываем ts:ответ-пользователя и сравниваем с mac из
токена — совпадёт только при верном коде."
  (when (and token user-answer)
    (let ((parts (split-sequence:split-sequence #\: token)))
      (when (= (length parts) 2)
        (let ((ts (ignore-errors (parse-integer (first parts)))))
          (when ts
            (let ((age (- (get-universal-time) ts)))
              (when (and (>= age 0) (<= age max-age))
                (let ((answer (string-trim " " user-answer)))
                  (and (plusp (length answer))
                       (string= (second parts)
                                (hmac-hex (format nil "~A:~A" (first parts) answer)))))))))))))



