;;; Lambda Runner — endless runner для JSCL
;;; Лямбда бежит через лес замыканий, собирает карри и избегает компиляторов.

(defpackage :lambda-runner
  (:use :cl)
  (:import-from :jscl/ffi)
  (:export #:start-lambda-runner
           #:game-loop-raw))

(in-package :lambda-runner)

;;; Состояние
(defvar *W* 640)
(defvar *H* 480)
(defvar *ctx* nil)
(defvar *score* 0)
(defvar *high-score* 0)
(defvar *speed* 3.0)
(defvar *tick* 0)
(defvar *game-over* nil)
(defvar *paused* nil)

;;; Игрок
(defvar *player* nil)
(defvar *jumping* nil)
(defvar *jump-vy* 0)
(defvar *ground-y* (- *H* 60))
(defvar *gravity* 0.6)
(defvar *jump-force* -12)

;;; Препятствия и предметы
(defvar *obstacles* nil)
(defvar *collectibles* nil)
(defvar *particles* nil)

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

(defun snd-jump () (play-snd #j"square" 300 600 0.1 0.15))
(defun snd-collect () (play-snd #j"sine" 800 1200 0.15 0.1))
(defun snd-hit () (play-snd #j"sawtooth" 200 50 0.2 0.3))
(defun snd-step () (play-snd #j"triangle" 80 60 0.08 0.03))

;;; Ввод
(defvar *keys* (make-array 256 :initial-element 0))
(defvar *prev-space* nil)
(defvar *prev-game-over* nil)
(defvar *pause-clicks* 0)
(defvar *reset-clicks* 0)
(defvar *prev-p* nil)
(defvar *prev-enter* nil)
(defvar *distance* 0)

(defun key-pressed (code)
  (= 1 (aref *keys* code)))

(defun read-input ()
  (let ((space-now (key-pressed 32)))
    (when (and space-now (not *prev-space*) (not *jumping*) (not *game-over*))
      (setf *jumping* t *jump-vy* *jump-force*)
      (snd-jump))
    (setf *prev-space* space-now))
  (let ((p-now (key-pressed 80)))
    (when (and p-now (not *prev-p*)) (incf *pause-clicks*))
    (setf *prev-p* p-now))
  (let ((enter-now (key-pressed 13)))
    (when (and enter-now (not *prev-enter*)) (incf *reset-clicks*))
    (setf *prev-enter* enter-now)))

;;; Спавн
(defun spawn-obstacle ()
  (let ((type (random 3)))
    (cond
      ((= type 0)
       ;; Замыкание — наземное препятствие
       (push (list :x (+ *W* 20) :y (- *ground-y* 28)
                    :w 20 :h 22 :type :closure :color "#6b7280")
             *obstacles*))
      ((= type 1)
       ;; Компилятор — высокое препятствие (нужно прыгнуть)
       (push (list :x (+ *W* 20) :y (- *ground-y* 48)
                   :w 18 :h 40 :type :compiler :color "#ef4444")
             *obstacles*))
      (t
       ;; Ловушка — узкое препятствие
       (push (list :x (+ *W* 20) :y (- *ground-y* 20)
                    :w 30 :h 16 :type :trap :color "#f59e0b")
             *obstacles*)))))

(defun spawn-collectible ()
  (push (list :x (+ *W* 20 (random 100))
              :y (- *ground-y* 60 (random 80))
              :w 16 :h 16 :type :curry :collected nil)
        *collectibles*))

(defun spawn-particle (x y color)
  (dotimes (i 3)
    (push (list :x x :y y
                :vx (- (random 4) 2)
                :vy (- (random 4) 2)
                :life 15 :color color)
          *particles*)))

;;; Инициализация
(defun reset ()
  (setf *score* 0 *speed* 3.0 *tick* 0 *distance* 0
        *game-over* nil *paused* nil
        *jumping* nil *jump-vy* 0
        *obstacles* nil *collectibles* nil *particles* nil
        *player* (list :x 80 :y (- *ground-y* 28)
                       :w 10 :h 22 :color "#f59e0b")))

;;; Отрисовка
(defun draw-lambda (x y w h color)
  (setf (jscl::oget *ctx* "fillStyle") (jscl/ffi:jsstring color))
  (setf (jscl::oget *ctx* "textAlign") #j"center")
  ((jscl::oget *ctx* "fillText") #j"λ" (+ x (/ w 2)) (+ y h -4)))

(defun draw-closure (o)
  (let ((x (getf o :x)) (y (getf o :y))
        (w (getf o :w)) (h (getf o :h))
        (c (getf o :color)))
    (setf (jscl::oget *ctx* "fillStyle") (jscl/ffi:jsstring c))
    ((jscl::oget *ctx* "fillRect") x y w h)
    (setf (jscl::oget *ctx* "fillStyle") #j"#fff")
    (setf (jscl::oget *ctx* "font") #j"bold 10px monospace")
    (setf (jscl::oget *ctx* "textAlign") #j"center")
    (cond
      ((eq (getf o :type) :closure)
       ((jscl::oget *ctx* "fillText") #j"λ" (+ x (/ w 2)) (+ y (/ h 2) 3)))
      ((eq (getf o :type) :compiler)
       ((jscl::oget *ctx* "fillText") #j"CC" (+ x (/ w 2)) (+ y (/ h 2) 3)))
      (t
       ((jscl::oget *ctx* "fillText") #j"//" (+ x (/ w 2)) (+ y (/ h 2) 3))))))

(defun draw-curry (c)
  (let ((x (getf c :x)) (y (getf c :y)))
    (setf (jscl::oget *ctx* "fillStyle") #j"#fbbf24")
    ((jscl::oget *ctx* "beginPath"))
    ((jscl::oget *ctx* "arc") (+ x 8) (+ y 8) 8 0 (* 2 3.14159))
    ((jscl::oget *ctx* "fill"))
    (setf (jscl::oget *ctx* "fillStyle") #j"#92400e")
    (setf (jscl::oget *ctx* "font") #j"bold 10px monospace")
    (setf (jscl::oget *ctx* "textAlign") #j"center")
    ((jscl::oget *ctx* "fillText") #j"C" (+ x 8) (+ y 12))))

(defun draw-particle (p)
  (setf (jscl::oget *ctx* "fillStyle") (jscl/ffi:jsstring (getf p :color)))
  ((jscl::oget *ctx* "fillRect") (getf p :x) (getf p :y) 3 3))

(defun draw-ground ()
  (setf (jscl::oget *ctx* "fillStyle") #j"#1a1a2e")
  ((jscl::oget *ctx* "fillRect") 0 *ground-y* *W* (- *H* *ground-y*))
  (setf (jscl::oget *ctx* "fillStyle") #j"#2d2d44")
  ((jscl::oget *ctx* "fillRect") 0 *ground-y* *W* 2))

(defun draw-hud ()
  (setf (jscl::oget *ctx* "fillStyle") #j"#fff")
  (setf (jscl::oget *ctx* "font") #j"14px monospace")
  (setf (jscl::oget *ctx* "textAlign") #j"left")
  ((jscl::oget *ctx* "fillText") (jscl/ffi:jsstring (format nil "Score: ~a" *score*)) 10 24)
  (setf (jscl::oget *ctx* "textAlign") #j"right")
  ((jscl::oget *ctx* "fillText") (jscl/ffi:jsstring (format nil "Best: ~a" *high-score*)) (- *W* 10) 24)
  (when *paused*
    (setf (jscl::oget *ctx* "fillStyle") #j"rgba(0,0,0,0.6)")
    ((jscl::oget *ctx* "fillRect") 0 0 *W* *H*)
    (setf (jscl::oget *ctx* "fillStyle") #j"#fff")
    (setf (jscl::oget *ctx* "font") #j"bold 24px monospace")
    (setf (jscl::oget *ctx* "textAlign") #j"center")
    ((jscl::oget *ctx* "fillText") #j"PAUSED" (/ *W* 2) (/ *H* 2)))
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

;;; Обновление
(defun update ()
  (when (or *paused* *game-over*) (return-from update))
  (incf *tick*)
  (incf *score*)
  (incf *speed* 0.005)
  ;; Звук шага каждые 80 единиц расстояния
  (incf *distance* *speed*)
  (when (>= *distance* 80)
    (decf *distance* 80)
    (snd-step))

  ;; Прыжок
  (when *jumping*
    (incf *jump-vy* *gravity*)
    (incf (getf *player* :y) *jump-vy*)
    (when (>= (getf *player* :y) (- *ground-y* (getf *player* :h)))
      (setf (getf *player* :y) (- *ground-y* (getf *player* :h))
            *jumping* nil *jump-vy* 0)))

  ;; Спавн препятствий
  (when (= (mod *tick* 80) 0)
    (spawn-obstacle))
  (when (= (mod *tick* 60) 0)
    (spawn-collectible))

  ;; Движение препятствий
  (setf *obstacles*
        (remove-if-not
         (lambda (o)
           (decf (getf o :x) *speed*)
           (> (getf o :x) -50))
         *obstacles*))

  ;; Движение collectibles
  (setf *collectibles*
        (remove-if-not
         (lambda (c)
           (decf (getf c :x) *speed*)
           (and (> (getf c :x) -50) (not (getf c :collected))))
         *collectibles*))

  ;; Движение частиц
  (setf *particles*
        (remove-if-not
         (lambda (p)
           (decf (getf p :life))
           (incf (getf p :x) (getf p :vx))
           (incf (getf p :y) (getf p :vy))
           (> (getf p :life) 0))
         *particles*))

  ;; Коллизия с препятствиями
  (let ((px (getf *player* :x)) (py (getf *player* :y))
        (pw (getf *player* :w)) (ph (getf *player* :h)))
    (dolist (o *obstacles*)
      (let ((ox (getf o :x)) (oy (getf o :y))
            (ow (getf o :w)) (oh (getf o :h)))
        (when (and (< ox (+ px pw)) (> (+ ox ow) px)
                   (< oy (+ py ph)) (> (+ oh oy) py))
          (setf *game-over* t)
          (when (> *score* *high-score*) (setf *high-score* *score*))
          (return)))))

  ;; Сбор карри
  (let ((px (getf *player* :x)) (py (getf *player* :y))
        (pw (getf *player* :w)) (ph (getf *player* :h)))
    (dolist (c *collectibles*)
      (unless (getf c :collected)
        (let ((cx (getf c :x)) (cy (getf c :y))
              (cw (getf c :w)) (ch (getf c :h)))
          (when (and (< cx (+ px pw)) (> (+ cx cw) px)
                     (< cy (+ py ph)) (> (+ ch cy) py))
            (setf (getf c :collected) t)
            (incf *score* 50)
            (spawn-particle (+ cx 8) (+ cy 8) "#fbbf24")))))))

;;; Игровой цикл
(defvar *prev-score* 0)

(defun game-loop-raw ()
  (setf *prev-score* *score*)
  (read-input)
  (when (plusp *pause-clicks*)
    (setf *pause-clicks* 0 *paused* (not *paused*)))
  (when (plusp *reset-clicks*)
    (setf *reset-clicks* 0)
    (when *game-over* (reset)))

  (setf (jscl::oget *ctx* "fillStyle") #j"#0a0a0a")
  ((jscl::oget *ctx* "fillRect") 0 0 *W* *H*)

  ;; Звёзды на фоне
  (when (= (mod *tick* 3) 0)
    (setf (jscl::oget *ctx* "fillStyle") #j"#333")
    ((jscl::oget *ctx* "fillRect") (random *W*) (random (- *ground-y* 20)) 1 1))

  (draw-ground)
  (update)

  ;; Игрок
  (draw-lambda (getf *player* :x) (getf *player* :y)
               (getf *player* :w) (getf *player* :h)
               (getf *player* :color))

  ;; Препятствия
  (dolist (o *obstacles*) (draw-closure o))

  ;; Карри
  (dolist (c *collectibles*) (draw-curry c))

  ;; Частицы
  (dolist (p *particles*) (draw-particle p))

  (draw-hud)

  ;; Звуки
  (when (and *game-over* (not *prev-game-over*) (not (zerop *score*)))
    (snd-hit))
  (when (> *score* (+ *prev-score* 50)) (snd-collect))
  (setf *prev-game-over* *game-over*))

;;; Точка входа
(defun start-lambda-runner ()
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
