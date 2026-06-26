;;; Lisp Invaders — клон Space Invaders для JSCL
;;; Всё на Common Lisp. Canvas через JS-обёртки, ввод через CL event listeners.

(in-package :cl-user)

;;; Состояние
(defvar *score* 0)
(defvar *lives* 3)
(defvar *level* 1)
(defvar *game-over* nil)
(defvar *paused* nil)
(defvar *W* 640)
(defvar *H* 480)
(defvar *player* nil)
(defvar *bullets* nil)
(defvar *bullet-cd* 0)
(defvar *enemy-bullets* nil)
(defvar *enemies* nil)
(defvar *e-dir* 1)
(defvar *e-speed* 0.5)
(defvar *e-step* nil)
(defvar *e-chance* 0.005)
(defvar *tick* 0)

;;; Ввод — JS только складывает e.keyCode в _pk[keyCode]
;;; Весь маппинг клавиш и логика — на CL.
;;; Коды клавиш (keyCode):
;;;   37=ArrowLeft  39=ArrowRight  32=Space  80=P  13=Enter
;;;   65=A  68=D  87=W  83=S

(defun key-pressed (code)
  (= 1 (#j:_kpc code)))

(defvar *input-left* nil)
(defvar *input-right* nil)
(defvar *input-space* nil)
(defvar *pause-clicks* 0)
(defvar *reset-clicks* 0)
(defvar *prev-p* nil)
(defvar *prev-enter* nil)

(defun read-input ()
  ;; Движение: стрелки + WASD
  (setf *input-left*  (or (key-pressed 37)   ; ArrowLeft
                          (key-pressed 65)))  ; A
  (setf *input-right* (or (key-pressed 39)   ; ArrowRight
                          (key-pressed 68)))  ; D
  ;; Стрельба: пробел
  (setf *input-space* (key-pressed 32))        ; Space
  ;; Пауза: P — детектируем rising edge (нажал → отпустил)
  (let ((p-now (key-pressed 80)))              ; P
    (when (and p-now (not *prev-p*))
      (incf *pause-clicks*))
    (setf *prev-p* p-now))
  ;; Рестарт: Enter — rising edge
  (let ((enter-now (key-pressed 13)))          ; Enter
    (when (and enter-now (not *prev-enter*))
      (incf *reset-clicks*))
    (setf *prev-enter* enter-now)))

;;; Спавн
(defun spawn ()
  (setf *enemies* nil)
  (let ((et (vector (list :l "defun"  :c "#ef4444" :p 10)
                    (list :l "lambda" :c "#f59e0b" :p 15)
                    (list :l "car"    :c "#3b82f6" :p 20)
                    (list :l "cdr"    :c "#8b5cf6" :p 20)
                    (list :l "quote"  :c "#ec4899" :p 25)
                    (list :l "cons"   :c "#14b8a6" :p 30))))
    (loop for r below 4 do
      (loop for c below 8 do
        (push (list :x (+ 60 (* c 65)) :y (+ 50 (* r 45))
                    :w 48 :h 28 :alive t
                    :type (aref et (mod r (length et)))
                    :f 0.0)
              *enemies*))))
  (setf *enemies* (nreverse *enemies*)))

(defun reset ()
  (setf *score* 0 *lives* 3 *level* 1
        *game-over* nil *paused* nil
        *bullets* nil *enemy-bullets* nil *bullet-cd* 0
        *e-dir* 1 *e-speed* 0.5 *e-step* nil *e-chance* 0.005
        *tick* 0)
  (setf *player* (list :x (- (/ *W* 2) 20) :y (- *H* 40)
                       :w 40 :h 24 :speed 5 :color "#22c55e"))
  (spawn))

;;; Отрисовка — JS-обёртки с ctx первым аргументом
;;; (#j:_fr #j:_ctx x y w h) — передаём ctx явно

(defun draw-str (s x y &key (f "14px monospace") (a "left") (c "#fff"))
  (#j:_fs #j:_ctx f)
  (#j:_ta #j:_ctx a)
  (#j:_sc #j:_ctx c)
  (#j:_ft #j:_ctx s x y))

(defun draw-player ()
  (let* ((p *player*) (x (getf p :x)) (y (getf p :y))
         (w (getf p :w)) (h (getf p :h)))
    (#j:_sc #j:_ctx (getf p :color))
    (#j:_bp #j:_ctx)
    (#j:_mt #j:_ctx (+ x (/ w 2)) y)
    (#j:_lt #j:_ctx (+ x w) (+ y h))
    (#j:_lt #j:_ctx x (+ y h))
    (#j:_cp #j:_ctx)
    (#j:_fl #j:_ctx)
    (#j:_sc #j:_ctx "#166534")
    (#j:_bp #j:_ctx)
    (#j:_ac #j:_ctx (+ x (/ w 2)) (+ y 8) 5 0 6.283)
    (#j:_fl #j:_ctx)
    (draw-str "defun" (+ x (/ w 2)) (+ y h -6)
              :f "bold 9px monospace" :a "center")))

(defun draw-enemies ()
  (dolist (e *enemies*)
    (when (getf e :alive)
      (let* ((x (getf e :x)) (y (getf e :y))
             (w (getf e :w)) (h (getf e :h))
             (tp (getf e :type))
             (color (getf tp :c)) (label (getf tp :l)))
        (#j:_sc #j:_ctx color)
        (#j:_fr #j:_ctx x y w h)
        (#j:_sc #j:_ctx "#000")
        (#j:_fr #j:_ctx (+ x 10) (+ y 8) 6 6)
        (#j:_fr #j:_ctx (+ x w -16) (+ y 8) 6 6)
        (#j:_sc #j:_ctx color)
        (#j:_fr #j:_ctx (+ x 12) (+ y 10) 2 2)
        (#j:_fr #j:_ctx (+ x w -14) (+ y 10) 2 2)
        (incf (getf e :f) 0.05)
        (let ((off (if (> (mod (getf e :f) 2.0) 1.0) 2.5 -2.5)))
          (#j:_fr #j:_ctx (+ x 6) (+ y h) 4 (+ 4 off))
          (#j:_fr #j:_ctx (+ x w -10) (+ y h) 4 (- 4 off)))
        (draw-str label (+ x (/ w 2)) (+ y (/ h 2) 3)
                  :f "bold 8px monospace" :a "center" :c "#000")))))

(defun draw-bullets ()
  (#j:_sc #j:_ctx "#22c55e")
  (dolist (b *bullets*)
    (#j:_fr #j:_ctx (- (getf b :x) 2) (getf b :y) 4 12))
  (#j:_sc #j:_ctx "#ef4444")
  (dolist (b *enemy-bullets*)
    (#j:_fr #j:_ctx (- (getf b :x) 1) (getf b :y) 3 8)))

(defun draw-hud ()
  (draw-str (format nil "Score: ~a" *score*) 10 24
            :f "bold 16px monospace" :c "#22c55e")
  (loop for i below *lives*
        do (draw-str "X" (- *W* 10 (* i 22)) 24
                     :f "bold 16px monospace" :a "right" :c "#ef4444"))
  (draw-str (format nil "Level ~a" *level*) (/ *W* 2) 24
            :f "12px monospace" :a "center" :c "#888")
  (when *paused*
    (#j:_sc #j:_ctx "rgba(0,0,0,0.6)")
    (#j:_fr #j:_ctx 0 0 *W* *H*)
    (draw-str "PAUSED" (/ *W* 2) (/ *H* 2)
              :f "bold 24px monospace" :a "center"))
  (when *game-over*
    (#j:_sc #j:_ctx "rgba(0,0,0,0.7)")
    (#j:_fr #j:_ctx 0 0 *W* *H*)
    (draw-str "GAME OVER" (/ *W* 2) (- (/ *H* 2) 10)
              :f "bold 28px monospace" :a "center" :c "#ef4444")
    (draw-str (format nil "Score: ~a" *score*) (/ *W* 2) (+ (/ *H* 2) 20)
              :f "16px monospace" :a "center")
    (draw-str "Press Enter" (/ *W* 2) (+ (/ *H* 2) 50)
              :f "14px monospace" :a "center" :c "#888")))

;;; Обновление
(defun update ()
  (when (or *paused* *game-over*) (return-from update))
  (incf *tick*)
  (when *input-left*
    (setf (getf *player* :x)
          (max 0 (- (getf *player* :x) (getf *player* :speed)))))
  (when *input-right*
    (setf (getf *player* :x)
          (min (- *W* (getf *player* :w))
               (+ (getf *player* :x) (getf *player* :speed)))))
  (when (> *bullet-cd* 0) (decf *bullet-cd*))
  (when (and *input-space* (<= *bullet-cd* 0))
    (push (list :x (+ (getf *player* :x) (/ (getf *player* :w) 2))
                :y (- (getf *player* :y) 4))
          *bullets*)
    (setf *bullet-cd* 12))
  (setf *bullets* (remove-if-not (lambda (b) (> (getf b :y) -10)) *bullets*))
  (dolist (b *bullets*) (decf (getf b :y) 5))
  (setf *enemy-bullets* (remove-if-not
                          (lambda (b) (< (getf b :y) (+ *H* 10)))
                          *enemy-bullets*))
  (dolist (b *enemy-bullets*) (incf (getf b :y) 3))
  ;; Limit max enemy bullets on screen
  (when (> (length *enemy-bullets*) 20)
    (setf *enemy-bullets* (subseq *enemy-bullets* 0 20)))
  (let ((alive (remove-if-not (lambda (e) (getf e :alive)) *enemies*)))
    (when (null alive)
      (incf *level*)
      (setf *e-speed* (+ 0.5 (* *level* 0.3)))
      (spawn)
      (return-from update))
    (let ((stepped nil))
      (if *e-step*
          (progn (dolist (e alive) (incf (getf e :y) 4))
                 (setf *e-dir* (- *e-dir*) *e-step* nil stepped t))
          (progn (dolist (e alive) (incf (getf e :x) (* *e-dir* *e-speed*)))))
      (unless stepped
        (let ((mn 999999) (mx -999999))
          (dolist (e alive)
            (setf mn (min mn (getf e :x))
                  mx (max mx (+ (getf e :x) (getf e :w)))))
          (when (or (>= mx (- *W* 10)) (<= mn 10))
            (setf *e-step* t))))
      ;; Враги стреляют рандомно: один выстрел каждые ~80 тиков
      (when (and (> *tick* 120) (= (mod *tick* 80) 0) (< (length *enemy-bullets*) 6))
        (when alive
          (let ((shooter (nth (random (length alive)) alive)))
            (push (list :x (+ (getf shooter :x) (/ (getf shooter :w) 2))
                        :y (+ (getf shooter :y) (getf shooter :h)))
                  *enemy-bullets*))))
      (dolist (b *bullets*)
        (dolist (e alive)
          (when (and (getf e :alive)
                     (> (getf b :x) (getf e :x))
                     (< (getf b :x) (+ (getf e :x) (getf e :w)))
                     (> (getf b :y) (getf e :y))
                     (< (getf b :y) (+ (getf e :y) (getf e :h))))
            (setf (getf e :alive) nil (getf b :y) -100)
            (incf *score* (getf (getf e :type) :p))))))
      (dolist (b *enemy-bullets*)
        (when (and (> (getf b :x) (getf *player* :x))
                   (< (getf b :x) (+ (getf *player* :x) (getf *player* :w)))
                   (> (getf b :y) (getf *player* :y))
                   (< (getf b :y) (+ (getf *player* :y) (getf *player* :h))))
          (setf (getf b :y) (+ *H* 100))
          (decf *lives*)
          (when (<= *lives* 0)
            (setf *game-over* t))))
      (dolist (e alive)
        (when (>= (+ (getf e :y) (getf e :h)) (getf *player* :y))
          (setf *game-over* t)))))

;;; Игровой цикл
(defun game-loop-raw ()
  ;; Read input from _ki array (JS updates _ki[0..4], CL reads here)
  (read-input)
  ;; Handle one-shot events (pause, reset)
  (when (plusp *pause-clicks*)
    (setf *pause-clicks* 0)
    (setf *paused* (not *paused*)))
  (when (plusp *reset-clicks*)
    (setf *reset-clicks* 0)
    (when *game-over* (reset)))
  (#j:_cl #j:_ctx *W* *H*)
  (update)
  (draw-player)
  (draw-enemies)
  (draw-bullets)
  (draw-hud)
  ;; Export state to JS globals for the JS game loop to read
  (#j:_exportGameState *score* *lives* (if *game-over* 1 0) (length (or *bullets* nil))))

;;; Точка входа
(defun start-lisp-invaders ()
  (reset))
