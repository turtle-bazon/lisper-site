;;; Конфигурация приложения.
;;;
;;; 2026-10-18: перешли с голого `(read s)` на cl-schema
;;; (https://github.com/turtle-bazon/cl-schema).
;;;
;;; Что это дало:
;;;   * `*default-config*` больше НЕ мёртвый — значения по умолчанию живут
;;;     в схеме (`:default`) и реально применяются. Раньше `read-config`
;;;     делал `(setf *config* (read s))`, то есть ЗАМЕНЯЛ плист целиком,
;;;     и дефолты работали только когда conf-файла нет вообще нигде.
;;;   * Опечатка в ключе (`:db-hots`) больше не игнорируется молча —
;;;     `validate-object` даёт "unknown key" (пока без :allow-extra).
;;;   * Тип проверяется на старте: `:port "8080"` (строка) — ошибка сразу,
;;;     а не `Type-error` посреди обработки первого запроса.
;;;   * `validate-file` читает файл с `*read-eval*` = NIL: конфиг не может
;;;     выполнить код (`#.(...)` больше не сработает).
;;;
;;; ВАЖНО: `*default-config*` оставлен как совместимость для кода, который
;;; ещё читает его напрямую, но источник истины — схема ниже. Не добавлять
;;; новые ключи только в `*default-config*`: они туда не попадут.

(in-package :lisper)

(defvar *config* nil
  "Validated config as a plist with all defaults applied (nil before read-config).")

(defparameter *default-config*
  '(:address "0.0.0.0"
    :port 8080
    :log-level :info
    :debug nil
    :db-host "127.0.0.1"
    :db-port 5432
    :db-name "lisper"
    :db-user "lisper"
    :db-password "lisper"
    :geo-db-path nil
    :admin-secret nil)
  "Legacy default plist. Kept so old code paths keep working; the real
   defaults live in the cl-schema spec below and are applied by read-config.")

(eval-when (:compile-toplevel :load-toplevel :execute)
  ;; define-accessors требует схему, существующую на этапе МАКРОРАСШИРЕНИЯ,
  ;; поэтому схема объявлена в eval-when. Порядок: схема → accessors.
  (cl-schema:define-schema :lisper/config
    '(:object
      ;; Не ставьте :allow-extra t «на всякий случай» — это отключит ровно
      ;; ту проверку, ради которой миграция делается. Если реальный
      ;; /etc/lisper.conf на сервере содержит ключ, которого нет здесь,
      ;; приложение упадёт на старте с понятным «unknown key :FOO» —
      ;; это лучше, чем молчаливый nil.
      :keys ((:address :string :default "0.0.0.0")
             (:port (:integer 1 65535) :default 8080)
             (:log-level :keyword :default :info)
             (:debug :boolean :default nil)

             (:db-host :string :default "127.0.0.1")
             (:db-port (:integer 1 65535) :default 5432)
             (:db-name :string :default "lisper")
             (:db-user :string :default "lisper")
             ;; Секреты/пути допускают nil: :geo-db-path nil отключает гео,
             ;; а отсутствие admin-secret не должно ломать старт.
             (:db-password (:or :string :null) :default "lisper")
             (:geo-db-path (:or :string :null) :default nil)
             (:admin-secret (:or :string :null) :default nil)
             (:form-secret (:or :string :null) :default nil)
             (:game-token (:or :string :null) :default nil)

             ;; nil означает «fallback на configured-site-url» (seo.lisp),
             ;; поэтому :null допустим, а не только строка.
             (:site-url (:or :string :null) :default nil)
             (:site-hosts (:or (:list :string) :null) :default nil)))))

;; cl-schema:define-accessors НЕ используется намеренно:
;;   * код читает конфиг через (config :key) в 14 местах — генерировать
;;     PREFIX-KEY ридеры значило бы менять все вызовы без выигрыша;
;;   * в v0.0.1.0 макрос не генерирует НИЧЕГО (проверено: 0 функций и без
;;     :except). В этой песочнице iterate 1.6.0 падает на
;;     "(COLLECT X) should be a symbol" даже при компиляции в fasl, хотя
;;     уже собранный код cl-schema с iterate работает — похоже на проблему
;;     окружения, а не макроса. При исправлении — включать отдельно.
(defun config-file-paths ()
  (list (probe-file "lisper.conf")
        (probe-file (merge-pathnames #p".lisper.conf" (user-homedir-pathname)))
        (probe-file (merge-pathnames #p".config/lisper/lisper.conf" (user-homedir-pathname)))
        (probe-file #p"/etc/lisper.conf")))

(defun config-report-errors (path errors)
  "Разбор валидации: путь conf-файла + список ошибок схемы. Все ошибки
   печатаются сразу — иначе при десятке проблем придётся чинить по одной."
  (format *error-output* "~&lisper: invalid config ~A~%" path)
  (dolist (e errors)
    (format *error-output* "  - ~A~%" e))
  (format *error-output* "  See lisper.conf.template for the full key list.~%"))

(defun alist->plist (alist)
  "cl-schema нормализует :object в АЛИСТ (:KEY . VALUE), а код читает
   конфиг через getf, которому нужен ПЛИСТ (:KEY VALUE). Ключевые слова
   регистронезависимы (CLHS: :port и :PORT — один символ), upper-case
   приводить не нужно.

   Ловушка: пара с nil-значением даёт (:KEY) — список длины 1, поэтому
   здесь (k . v), а не (k v)."
  (loop for (key . value) in alist
        append (list key value)))

(defun install-validated (normalized errors path)
  "Принять нормализованный конфиг или упасть с перечнем проблем. Ошибка
   НАМЕРЕННА фатальная: опечатка в ключе не должна превращаться в молчаливый
   nil, всплывающий как 500 через несколько месяцев."
  (if errors
      (progn (config-report-errors path errors)
             (error "lisper: refusing to start with an invalid config"))
      (setf *config* (alist->plist normalized))))

(defun read-config ()
  "Load and VALIDATE the first config file found. Applies schema defaults.
   Errors are fatal — см. install-validated."
  (let ((path (find-if #'identity (config-file-paths))))
    (if (null path)
        ;; Файла нет — валидируем встроенные дефолты, чтобы и они проверялись.
        (progn
         (multiple-value-bind (normalized errors)
             (cl-schema:validate :lisper/config *default-config* :config)
           (install-validated normalized errors "<built-in defaults>"))
         (format t "~&lisper: no config file found, using built-in defaults~%"))
        (multiple-value-bind (normalized errors)
            (cl-schema:validate-file :lisper/config path)
          (install-validated normalized errors path))))
  *config*)

(defun config (key &optional default)
  "Value of KEY from the validated config, or DEFAULT."
  (or (getf *config* key) default))
