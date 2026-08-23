(in-package :lisper)

(defun main (&optional args)
  ;; buildapp кладёт путь к исполняемому файлу ПЕРВЫМ элементом args;
  ;; отбрасываем его (эвристика: содержит "/" или называется "lisper").
  ;; При запуске под sbcl --eval args=nil и просто стартует сервер.
  (let ((argv (cond
                ((null args) nil)
                ((and (first args)
                      (or (find #\/ (first args) :test #'char=)
                          (string= (first args) "lisper")))
                 (rest args))
                (t args))))
    (cond
      ;; без аргументов — как раньше, просто запускаем сервер
      ((null argv) (start-server))
      ;; явный `serve`/`server`
      ((member (first argv) '("serve" "server") :test #'string=)
       (start-server))
      ;; `import` без/с неверным подкомандом: clingon:exit в buildapp-образе
      ;; не отдаёт коды ошибок наружу, поэтому валидируем форму сами
      ((and (string= (first argv) "import")
            (not (member (second argv) '("forum" "content") :test #'string=)))
       (format *error-output* "~&usage: lisper import <forum|content> [--conf FILE] [--json FILE] [--force]~%")
       (uiop:quit 64))
      ;; всё остальное — CLI (help, import forum|content, ...)
      (t (clingon:run (cli/top-level) argv)))))
