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
