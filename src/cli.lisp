;;; CLI на clingon: подкоманды `import forum|content` (импорт старого
;;; lisper.ru, см. legacy-import.lisp) и `serve` (веб-сервер).
;;; Диспетчеризация — в main.lisp: без аргументов запускается сервер,
;;; всё остальное уходит в clingon.

(in-package :lisper)

(defun cli/serve-handler (cmd)
  "Обработчик `lisper serve` — обычный запуск сайта."
  (declare (ignore cmd))
  (start-server))

(defun cli/import-forum-handler (cmd)
  "Обработчик `lisper import forum`. Ошибки -> печать + exit 1."
  (let ((conf (clingon:getopt cmd :conf))
        (json (clingon:getopt cmd :json))
        (force (clingon:getopt cmd :force)))
    ;; uiop:quit напрямую: clingon:exit не выходит в некоторых образах
    (handler-case (import-forum-main conf json force)
      (error (e)
        (format *error-output* "~&~A~%" e)
        (uiop:quit 1)))))

(defun cli/import-content-handler (cmd)
  "Обработчик `lisper import content`."
  (let ((conf (clingon:getopt cmd :conf))
        (json (clingon:getopt cmd :json))
        (force (clingon:getopt cmd :force)))
    (handler-case (import-content-main conf json force)
      (error (e)
        (format *error-output* "~&~A~%" e)
        (uiop:quit 1)))))

(defun cli/import-command ()
  "Группа `lisper import`: импорт старого форума и контента."
  (clingon:make-command
   :name "import"
   :description "импорт старого контента lisper.ru из wayback JSON"
   :usage "[--conf FILE] [--json FILE] [--force] <forum|content>"
   :sub-commands
   (list
    (clingon:make-command
     :name "forum"
     :description "архив форума: категории «Архив: …» + темы/посты от oldlisper;
повторный запуск ДУБЛИРУЕТ темы (вставка без дедупликации)"
     :usage "[--conf FILE] [--json FILE] [--force]"
     :options (list (cli/conf-option)
                    (cli/json-option "wayback/forum_parsed.json")
                    (cli/force-option))
     :handler #'cli/import-forum-handler)
    (clingon:make-command
     :name "content"
     :description "блог/статьи/wiki от oldlisper; --force удаляет его посты
перед вставкой (чистый реимпорт)"
     :usage "[--conf FILE] [--json FILE] [--force]"
     :options (list (cli/conf-option)
                    (cli/json-option "wayback/content_parsed.json")
                    (cli/force-option))
     :handler #'cli/import-content-handler))))

(defun cli/conf-option ()
  (clingon:make-option :string
                       :short-name #\c
                       :long-name "conf"
                       :initial-value "lisper.conf"
                       :description "путь к .conf файлу (настройки БД)"
                       :key :conf))

(defun cli/json-option (default)
  (clingon:make-option :string
                       :short-name #\j
                       :long-name "json"
                       :initial-value default
                       :description "путь к распарсенному wayback JSON"
                       :key :json))

(defun cli/force-option ()
  (clingon:make-option :boolean/true
                       :long-name "force"
                       :description "разрешить работу с непустой БД"
                       :key :force))

(defun cli/top-level ()
  (clingon:make-command
   :name "lisper"
   :description "lisper — сайт о Common Lisp"
   :version (asdf:component-version (asdf:find-system :lisper))
   :authors '("turtle-bazon")
   :license "GPL-3.0"
   :sub-commands
   (list
    ;; serve — явный запуск сервера; без аргументов main тоже запускает сервер
    (clingon:make-command
     :name "serve"
     :description "запустить веб-сервер (то же, что запуск без аргументов)"
     :handler #'cli/serve-handler)
    (cli/import-command))))

(defun cli-run (argv)
  "Точка входа CLI для main. Возвращает код выхода (не выходит сама)."
  (clingon:run (cli/top-level) argv))
