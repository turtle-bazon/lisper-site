;;; Paren Matcher — игра на сопоставление скобок для JSCL
;;; Скобки падают сверху, игрок ловит и соединяет пары.

(defpackage :paren-matcher
  (:use :cl)
  (:import-from :jscl/ffi)
  (:export #:start-paren-matcher
           #:game-loop-raw))

(in-package :paren-matcher)

;;; Состояние
(defvar *W* 640)
(defvar *H* 480)
(defvar *ctx* nil)
(defvar *score* 0)
(defvar *high-score* 0)
(defvar *lives* 5)
(defvar *max-lives* 5)
(defvar *level* 1)
(defvar *tick* 0)
(defvar *game-over* nil)
(defvar *paused* nil)
(defvar *fall-speed* 2.0)

;;; Игрок
(defvar *player* nil)

;;; Скобки
(defvar *brackets* nil)
(defvar *stack* nil)
(defvar *particles* nil)
(defvar *streak* 0)
(defvar *floats* nil)

;;; Ввод
(defvar *keys* (make-array 256 :initial-element 0))
(defvar *prev-p* nil)
(defvar *prev-enter* nil)
(defvar *prev-space* nil)
(defvar *pause-clicks* 0)
(defvar *reset-clicks* 0)

(defun key-pressed (code)
  (= 1 (aref *keys* code)))

;;; Сопоставление скобок
(defvar *pairs*
  (list (cons "(" ")")
        (cons "[" "]")
        (cons "{" "}")))

(defun open-paren-p (s)
  (dolist (p *pairs*)
    (when (string= s (car p)) (return t))))

(defun close-paren-p (s)
  (dolist (p *pairs*)
    (when (string= s (cdr p)) (return t))))

(defun matching-open (close)
  (dolist (p *pairs*)
    (when (string= close (cdr p)) (return (car p)))))

(defun matching-close (open)
  (dolist (p *pairs*)
    (when (string= open (car p)) (return (cdr p)))))

;;; Цвета скобок
(defun bracket-color (s)
  (cond
    ((or (string= s "(") (string= s ")")) "#3b82f6")
    ((or (string= s "[") (string= s "]")) "#22c55e")
    ((or (string= s "{") (string= s "}")) "#eab308")
    (t "#fff")))

;;; Спавн
(defun spawn-bracket ()
  (snd-spawn)
  (let* ((types '("(" ")" "[" "]" "{" "}"))
         (s (nth (random (length types)) types))
         (x (+ 40 (random (- *W* 80)))))
    (push (list :x x :y -20 :s s :speed (+ *fall-speed* (random 1.0)))
          *brackets*)))

(defun spawn-particle (x y color)
  (dotimes (i 4)
    (push (list :x x :y y
                :vx (- (random 6) 3)
                :vy (- (random 6) 3)
                :life 20 :color color)
          *particles*)))

(defun spawn-float (x y text color)
  (push (list :x x :y y :text text :color color :life 40)
        *floats*))

;;; Инициализация
(defun reset ()
  (setf *score* 0 *lives* 5 *level* 1 *tick* 0
        *fall-speed* 2.0 *streak* 0
        *game-over* nil *paused* nil
        *brackets* nil *stack* nil *particles* nil *floats* nil
        *player* (list :x (- (/ *W* 2) 30) :y (- *H* 40)
                       :w 60 :h 12 :color "#3b82f6")))

;;; Отрисовка
(defun draw-player ()
  (let ((x (getf *player* :x)) (y (getf *player* :y))
        (w (getf *player* :w)) (h (getf *player* :h)))
    (setf (jscl::oget *ctx* "fillStyle") (jscl/ffi:jsstring (getf *player* :color)))
    ((jscl::oget *ctx* "fillRect") x y w h)
    (setf (jscl::oget *ctx* "fillStyle") #j"#fff")
    (setf (jscl::oget *ctx* "font") #j"bold 10px monospace")
    (setf (jscl::oget *ctx* "textAlign") #j"center")
    ((jscl::oget *ctx* "fillText") #j"()" (+ x (/ w 2)) (- y 4))))

(defun draw-bracket (b)
  (let ((x (getf b :x)) (y (getf b :y)) (s (getf b :s)))
    (setf (jscl::oget *ctx* "fillStyle") (jscl/ffi:jsstring (bracket-color s)))
    (setf (jscl::oget *ctx* "font") #j"bold 24px monospace")
    (setf (jscl::oget *ctx* "textAlign") #j"center")
    ((jscl::oget *ctx* "fillText") (jscl/ffi:jsstring s) x (+ y 20))))

(defun draw-stack ()
  (let ((sx (- *W* 10)) (sy 50))
    (setf (jscl::oget *ctx* "fillStyle") #j"#555")
    (setf (jscl::oget *ctx* "font") #j"12px monospace")
    (setf (jscl::oget *ctx* "textAlign") #j"right")
    ((jscl::oget *ctx* "fillText") (jscl/ffi:jsstring (format nil "Stack (~a):" (length *stack*))) sx sy)
    (let ((cx (- *W* 30)))
      (setf (jscl::oget *ctx* "textAlign") #j"center")
      (dolist (s *stack*)
        (setf (jscl::oget *ctx* "fillStyle") (jscl/ffi:jsstring (bracket-color s)))
        (setf (jscl::oget *ctx* "font") #j"bold 18px monospace")
        ((jscl::oget *ctx* "fillText") (jscl/ffi:jsstring s) cx (+ sy 20))
        (decf cx 22)))))

(defun draw-particle (p)
  (setf (jscl::oget *ctx* "fillStyle") (jscl/ffi:jsstring (getf p :color)))
  ((jscl::oget *ctx* "fillRect") (getf p :x) (getf p :y) 3 3))

(defun draw-float (f)
  (setf (jscl::oget *ctx* "fillStyle") (jscl/ffi:jsstring (getf f :color)))
  (setf (jscl::oget *ctx* "font") #j"bold 16px monospace")
  (setf (jscl::oget *ctx* "textAlign") #j"center")
  ((jscl::oget *ctx* "fillText") (jscl/ffi:jsstring (getf f :text)) (getf f :x) (getf f :y))
  (decf (getf f :y) 1.0))

(defun draw-hud ()
  (setf (jscl::oget *ctx* "fillStyle") #j"#fff")
  (setf (jscl::oget *ctx* "font") #j"14px monospace")
  (setf (jscl::oget *ctx* "textAlign") #j"left")
  ((jscl::oget *ctx* "fillText") (jscl/ffi:jsstring (format nil "Score: ~a" *score*)) 10 24)
  (setf (jscl::oget *ctx* "textAlign") #j"right")
  ((jscl::oget *ctx* "fillText") (jscl/ffi:jsstring (format nil "Best: ~a" *high-score*)) (- *W* 10) 24)
  (setf (jscl::oget *ctx* "textAlign") #j"center")
  ((jscl::oget *ctx* "fillText") (jscl/ffi:jsstring (format nil "Level: ~a" *level*)) (/ *W* 2) 24)
  ;; Lives
  (setf (jscl::oget *ctx* "fillStyle") #j"#ef4444")
  (setf (jscl::oget *ctx* "font") #j"16px monospace")
  (setf (jscl::oget *ctx* "textAlign") #j"left")
  (let ((lx 10) (ly (+ *H* -15)))
    (dotimes (i *lives*)
      ((jscl::oget *ctx* "fillText") #j"♥" (+ lx (* i 20)) ly)))
  ;; Streak
  (when (>= *streak* 2)
    (setf (jscl::oget *ctx* "fillStyle") #j"#22c55e")
    (setf (jscl::oget *ctx* "font") #j"12px monospace")
    (setf (jscl::oget *ctx* "textAlign") #j"left")
    ((jscl::oget *ctx* "fillText")
     (jscl/ffi:jsstring (format nil "Streak: ~a (next heal: ~a)" *streak* (- 2 (mod *streak* 2))))
     10 (+ *H* -30)))
  ;; Stack overflow warning
  (when (>= (length *stack*) 4)
    (setf (jscl::oget *ctx* "fillStyle")
          (if (>= (length *stack*) 5) #j"#ef4444" #j"#f59e0b"))
    (setf (jscl::oget *ctx* "font") #j"bold 14px monospace")
    (setf (jscl::oget *ctx* "textAlign") #j"center")
    ((jscl::oget *ctx* "fillText")
     (jscl/ffi:jsstring (format nil "Stack: ~a/6" (length *stack*)))
     (/ *W* 2) (+ *H* -15)))
  ;; Paused
  (when *paused*
    (setf (jscl::oget *ctx* "fillStyle") #j"rgba(0,0,0,0.6)")
    ((jscl::oget *ctx* "fillRect") 0 0 *W* *H*)
    (setf (jscl::oget *ctx* "fillStyle") #j"#fff")
    (setf (jscl::oget *ctx* "font") #j"bold 24px monospace")
    (setf (jscl::oget *ctx* "textAlign") #j"center")
    ((jscl::oget *ctx* "fillText") #j"PAUSED" (/ *W* 2) (/ *H* 2)))
  ;; Game over
  (when *game-over*
    (setf (jscl::oget *ctx* "fillStyle") #j"rgba(0,0,0,0.7)")
    ((jscl::oget *ctx* "fillRect") 0 0 *W* *H*)
    (setf (jscl::oget *ctx* "fillStyle") #j"#ef4444")
    (setf (jscl::oget *ctx* "font") #j"bold 28px monospace")
    (setf (jscl::oget *ctx* "textAlign") #j"center")
    ((jscl::oget *ctx* "fillText") #j"GAME OVER" (/ *W* 2) (- (/ *H* 2) 10))
    (setf (jscl::oget *ctx* "fillStyle") #j"#fff")
    (setf (jscl::oget *ctx* "font") #j"16px monospace")
    ((jscl::oget *ctx* "fillText") (jscl/ffi:jsstring (format nil "Score: ~a" *score*)) (/ *W* 2) (+ (/ *H* 2) 20))
    (setf (jscl::oget *ctx* "fillStyle") #j"#888")
    (setf (jscl::oget *ctx* "font") #j"14px monospace")
    ((jscl::oget *ctx* "fillText") #j"Press Enter" (/ *W* 2) (+ (/ *H* 2) 50))))

;;; Звук
(defvar *ac* nil)

(defun ensure-audio-ctx ()
  (unless *ac*
    (setf *ac* (#j:Reflect:construct (or #j:AudioContext #j:webkitAudioContext) (#j:Array)))))

(defun play-snd (wave-type freq-start freq-end vol dur)
  (ensure-audio-ctx)
  (let* ((osc ((jscl::oget *ac* "createOscillator")))
         (gain ((jscl::oget *ac* "createGain")))
         (freq (jscl::oget osc "frequency"))
         (vol-g (jscl::oget gain "gain"))
         (now (jscl::oget *ac* "currentTime")))
    (setf (jscl::oget osc "type") wave-type)
    ((jscl::oget freq "setValueAtTime") freq-start now)
    ((jscl::oget freq "exponentialRampToValueAtTime") freq-end (+ now dur))
    ((jscl::oget vol-g "setValueAtTime") vol now)
    ((jscl::oget vol-g "exponentialRampToValueAtTime") 0.001 (+ now dur))
    ((jscl::oget osc "connect") gain)
    ((jscl::oget gain "connect") (jscl::oget *ac* "destination"))
    ((jscl::oget osc "start") now)
    ((jscl::oget osc "stop") (+ now dur))))

(defun snd-match () (play-snd #j"sine" 600 1200 0.15 0.1))
(defun snd-catch () (play-snd #j"triangle" 400 600 0.1 0.08))
(defun snd-miss () (play-snd #j"sawtooth" 300 100 0.2 0.2))
(defun snd-overflow () (play-snd #j"square" 200 50 0.25 0.4))
(defun snd-levelup () (play-snd #j"sine" 400 800 0.1 0.3))
(defun snd-spawn () (play-snd #j"sine" 1200 800 0.05 0.05))

;;; Обновление
(defun update ()
  (when (or *paused* *game-over*) (return-from update))
  (incf *tick*)

  ;; Движение игрока
  (let ((speed 6))
    (when (or (key-pressed 37) (key-pressed 65)) (decf (getf *player* :x) speed))
    (when (or (key-pressed 39) (key-pressed 68)) (incf (getf *player* :x) speed))
    ;; Ограничение по экрану
    (when (< (getf *player* :x) 0) (setf (getf *player* :x) 0))
    (when (> (getf *player* :x) (- *W* (getf *player* :w)))
      (setf (getf *player* :x) (- *W* (getf *player* :w)))))

  ;; Спавн скобок
  (let ((interval (max 20 (- 60 (* *level* 5)))))
    (when (= (mod *tick* interval) 0)
      (spawn-bracket)))

  ;; Движение скобок — если закрывающая улетела вниз и её пара на вершине стека, штраф
  (let ((off-screen nil))
    (setf *brackets*
          (remove-if-not
           (lambda (b)
             (incf (getf b :y) (getf b :speed))
             (if (>= (getf b :y) (+ *H* 10))
                 (progn
                   (push b off-screen)
                   nil)
                 t))
           *brackets*))
    ;; Проверяем улетевшие скобки
    (dolist (b off-screen)
      (let ((s (getf b :s)))
        (cond
         ;; Закрывающая совпала с вершиной стека, но игрок не поймал — штраф, стек не трогаем
         ((and (close-paren-p s)
               *stack*
               (string= (first *stack*) (matching-open s)))
          (setf *streak* 0)
          (decf *lives*)
          (snd-miss)
          (spawn-float (getf b :x) (- *H* 30) "-1 ♥" "#ef4444")
          (when (<= *lives* 0)
            (setf *game-over* t)
            (when (> *score* *high-score*) (setf *high-score* *score*))))
         ;; Открывающая улетела при пустом стеке — тоже штраф
         ((and (open-paren-p s)
               (not *stack*))
          (setf *streak* 0)
          (decf *lives*)
          (snd-miss)
          (spawn-float (getf b :x) (- *H* 30) "-1 ♥" "#ef4444")
          (when (<= *lives* 0)
            (setf *game-over* t)
            (when (> *score* *high-score*) (setf *high-score* *score*))))))))

  ;; Автосбор: если скобка достигла платформы
  (let ((px (getf *player* :x)) (py (getf *player* :y))
        (pw (getf *player* :w)))
    (setf *brackets*
          (remove-if-not
           (lambda (b)
             (let ((bx (getf b :x)) (by (getf b :y)) (bs (getf b :s)))
               (if (and (>= bx (- px 10)) (<= bx (+ px pw 10))
                        (>= by (- py 10)) (<= by (+ py 20)))
                   (progn
                     (snd-catch)
                     (spawn-particle bx by (bracket-color bs))
                      (cond
                       ;; Открывающая — всегда в стек
                       ((open-paren-p bs)
                        (push bs *stack*))
                       ;; Закрывающая совпадает с верхом стека — match
                       ((and (>= (length *stack*) 1)
                             (open-paren-p (first *stack*))
                             (string= bs (matching-close (first *stack*))))
                        ;; Вложенность = кол-во открывающих в стеке
                        (let* ((depth (count-if #'open-paren-p *stack*))
                               (mult (expt 2 (1- depth))))
                          (pop *stack*)
                          (incf *score* (* 10 *level* mult))
                          (incf *streak*)
                          (snd-match)
                          (spawn-particle bx (- by 10) "#22c55e")
                          (spawn-particle bx (- by 20) "#22c55e")
                          (when (> mult 1)
                            (spawn-float bx (- by 30) (format nil "~ax!" mult) "#eab308"))
                          ;; Хил каждые 2 стрика
                          (when (and (>= *streak* 2) (= (mod *streak* 2) 0)
                                     (< *lives* *max-lives*))
                            (incf *lives*)
                            (snd-levelup)
                            (spawn-float bx (- by 50) "+1 ♥" "#3b82f6")
                            (spawn-particle bx (- by 50) "#3b82f6")
                            (spawn-particle bx (- by 60) "#3b82f6"))
                          ;; Уровень
                          (when (and (> *score* 0) (= (mod *score* 100) 0))
                            (incf *level*)
                            (setf *fall-speed* (+ 2.0 (* *level* 0.3)))
                            (snd-levelup))))
                       ;; Закрывающая НЕ совпадает — штраф
                        ((close-paren-p bs)
                         (setf *streak* 0)
                         (decf *lives*)
                         (snd-miss)
                         (spawn-float bx (- by 20) "-1 ♥" "#ef4444")
                         (when (<= *lives* 0)
                           (setf *game-over* t)
                           (when (> *score* *high-score*) (setf *high-score* *score*))))
                        ;; Прочее
                        (t nil))
                     nil)
                   t)))
           *brackets*)))

  ;; Проверка переполнения стека — минус жизнь, очистка стека
  (when (>= (length *stack*) 6)
    (setf *stack* nil *streak* 0)
    (decf *lives*)
    (snd-overflow)
    (when (<= *lives* 0)
      (setf *game-over* t)
      (when (> *score* *high-score*) (setf *high-score* *score*))))

  ;; Частицы
  (setf *particles*
        (remove-if-not
         (lambda (p)
           (decf (getf p :life))
           (incf (getf p :x) (getf p :vx))
           (incf (getf p :y) (getf p :vy))
            (> (getf p :life) 0))
         *particles*))

  ;; Частицы текста
  (setf *floats*
        (remove-if-not
         (lambda (f)
           (decf (getf f :life))
           (> (getf f :life) 0))
         *floats*)))

;;; Ввод
(defun read-input ()
  (let ((p-now (key-pressed 80)))
    (when (and p-now (not *prev-p*)) (incf *pause-clicks*))
    (setf *prev-p* p-now))
  (let ((enter-now (key-pressed 13)))
    (when (and enter-now (not *prev-enter*)) (incf *reset-clicks*))
    (setf *prev-enter* enter-now)))

;;; Игровой цикл
(defun game-loop-raw ()
  (read-input)
  (when (plusp *pause-clicks*)
    (setf *pause-clicks* 0 *paused* (not *paused*)))
  (when (plusp *reset-clicks*)
    (setf *reset-clicks* 0)
    (when *game-over* (reset)))

  (setf (jscl::oget *ctx* "fillStyle") #j"#0a0a0a")
  ((jscl::oget *ctx* "fillRect") 0 0 *W* *H*)

  (update)
  (draw-stack)
  (draw-player)
  (dolist (b *brackets*) (draw-bracket b))
  (dolist (p *particles*) (draw-particle p))
  (dolist (f *floats*) (draw-float f))
  (draw-hud))

;;; Точка входа
(defun start-paren-matcher ()
  (ensure-audio-ctx)
  (setf *ctx* ((jscl::oget (#j:document:getElementById #j"game-canvas") "getContext") #j"2d"))
  (let ((doc #j:document))
    ((jscl::oget doc "addEventListener")
     #j"keydown"
     (lambda (e)
       (let ((code (jscl::oget e "keyCode")))
         (setf (aref *keys* code) 1)
         (when (or (= code 37) (= code 38) (= code 39) (= code 40) (= code 32))
           ((jscl::oget e "preventDefault"))))))
    ((jscl::oget doc "addEventListener")
     #j"keyup"
     (lambda (e)
       (setf (aref *keys* (jscl::oget e "keyCode")) 0))))
  (reset))
