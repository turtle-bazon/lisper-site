;;;; Unit-тесты proof-of-work (src/antispam.lisp).
;;;; Запуск из корня репо:
;;;;   POW_TEST_ROOT=$PWD sbcl --non-interactive --load tests/pow/pow.test.lisp
;;;; Вывод совместим с run-tests.sh: строки "PASS: ..." / "FAIL: ..." и итог "PASS=n FAIL=m".

(ql:quickload :ironclad :silent t)
(ql:quickload :split-sequence :silent t)

(defpackage :lisper (:use :cl))
(in-package :lisper)

;;; Стаб config: без .conf секрета hmac-hex падает в дефолт — детерминированно.
(defparameter *root*
  (or (uiop:getenv "POW_TEST_ROOT")
      (uiop:pathname-parent-directory-pathname
       (uiop:pathname-parent-directory-pathname
        (ignore-errors (uiop:current-lisp-file-pathname))))
      (uiop:getcwd)))

(defun config (&rest keys)
  (declare (ignore keys))
  nil)

(let ((src (merge-pathnames "src/antispam.lisp" *root*)))
  (assert (probe-file src) () "antispam.lisp not found: ~a" src)
  (load src))

(defparameter *pass* 0)
(defparameter *fail* 0)

(defun check (name ok)
  (if ok
      (progn (incf *pass*) (format t "PASS: ~a~%" name))
      (progn (incf *fail*) (format t "FAIL: ~a~%" name))))

(defun mine (salt diff)
  (loop for i from 0
        when (>= (leading-zero-bits
                  (ironclad:digest-sequence
                   :sha256
                   (concatenate '(vector (unsigned-byte 8))
                                (ironclad:ascii-string-to-byte-array salt)
                                (ironclad:ascii-string-to-byte-array
                                 (write-to-string i)))))
                 diff)
          return i))

;;; --- leading-zero-bits

(check "lzb: #xFF.. = 0 бит"            (= 0 (leading-zero-bits #(255 0 0))))
(check "lzb: #x00FF.. = 8 бит"          (= 8 (leading-zero-bits #(0 255 0))))
(check "lzb: #x01.. = 7 бит"            (= 7 (leading-zero-bits #(1 0 0))))
(check "lzb: нулевые байты = 24"        (= 24 (leading-zero-bits #(0 0 0))))
(check "lzb: #xF0.. = 0"                (= 0 (leading-zero-bits #(240 1 2))))
;; sha256("abc777") = b135d404... -> первый байт 0xb1 -> 0 ведущих нулей
(check "lzb: sha256('abc777') = 0"
       (= 0 (leading-zero-bits
             (ironclad:digest-sequence :sha256
                                       (ironclad:ascii-string-to-byte-array "abc777")))))
;; sha256("") = e3b0c44298fc1c14... -> 0xe3=11100011 -> 0
(check "lzb: sha256('') = 0"
       (= 0 (leading-zero-bits
             (ironclad:digest-sequence :sha256 (ironclad:ascii-string-to-byte-array "")))))

;;; --- make-pow-challenge / verify-pow

(let* ((token (make-pow-challenge))
       (parts (split-sequence:split-sequence #\: token))
       (ts-str (first parts)) (diff-str (second parts))
       (salt (third parts)) (mac (fourth parts))
       (diff (parse-integer diff-str)))
  (check "challenge: 4 части ts:diff:salt:mac" (= (length parts) 4))
  (check "challenge: diff = *pow-difficulty*" (= diff *pow-difficulty*))
  (check "challenge: salt hex/24"
         (and (= (length salt) 24)
              (every (lambda (c) (digit-char-p c 16)) salt)))
  (check "challenge: mac сходится"
         (string= mac (hmac-hex (format nil "~A:~A:~A" ts-str diff-str salt))))

  ;; валидный nonce проходит и переиспользуется (stateless)
  (let ((nonce (mine salt diff)))
    (format t "INFO: mined nonce=~a for diff=~a~%" nonce diff)
    (check "verify: валидный nonce -> T"
           (eq (verify-pow token (write-to-string nonce)) t))
    (check "verify: повторно -> T (stateless)"
           (eq (verify-pow token (write-to-string nonce)) t))
    (check "verify: nonce+1 -> NIL"
           (eq (verify-pow token (write-to-string (1+ nonce))) nil))
    (check "verify: nonce 777 -> NIL" (eq (verify-pow token "777") nil))
    (check "verify: nonce 0 -> NIL"   (eq (verify-pow token "0") nil))
    ;; просроченный токен: подписываем ts двухчасовой давности
    (let* ((old-ts (- (get-universal-time) 7200))
           (msg (format nil "~A:~A:~A" old-ts diff-str salt))
           (old-token (format nil "~A:~A" msg (hmac-hex msg))))
      (check "verify: просроченный токен -> NIL"
             (eq (verify-pow old-token (write-to-string nonce)) nil))))

  ;; подделки токена
  (check "verify: подделанный mac -> NIL"
         (eq (verify-pow (format nil "~A:~A:~A:~A" ts-str diff-str salt
                                 (make-string 64 :initial-element #\0))
                         "123")
             nil))
  (check "verify: подменённая сложность -> NIL"
         (eq (verify-pow (format nil "~A:22:~A:~A" ts-str salt mac) "123") nil))
  (check "verify: другой ts (mac не сойдётся) -> NIL"
         (let ((fake-ts (write-to-string (+ (parse-integer ts-str) 3600))))
           (eq (verify-pow (format nil "~A:~A:~A:~A" fake-ts diff-str salt mac) "123")
               nil)))
  (check "verify: мусорный токен -> NIL" (eq (verify-pow "1:2:aa:bb" "5") nil))
  (check "verify: не-числовой nonce -> NIL" (eq (verify-pow token "abc") nil))
  (check "verify: NIL-аргументы -> NIL"
         (and (eq (verify-pow token nil) nil)
              (eq (verify-pow nil "5") nil)
              (eq (verify-pow nil nil) nil))))

;;; --- форма-токены рядом (не сломались общие хелперы)
(check "form-token: verify-form-token мгновенно -> NIL (min-age)"
       (eq (verify-form-token (make-form-token)) nil))

(format t "PASS=~a FAIL=~a~%" *pass* *fail*)
(uiop:quit (if (zerop *fail*) 0 1))