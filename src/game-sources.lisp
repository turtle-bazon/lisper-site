(in-package :lisper)

;;; Автоматически сгенерировано build-resources.lisp
;;; Источники: jscl-games/*.{lisp,js}

(defparameter *game-sources* '
  (
    ("lambda-runner" "cl" ";;; Lambda Runner — endless runner для JSCL
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
  (let* ((osc ((jscl::oget *ac* \"createOscillator\")))
         (gain ((jscl::oget *ac* \"createGain\")))
         (freq (jscl::oget osc \"frequency\"))
         (vol-g (jscl::oget gain \"gain\"))
         (now (jscl::oget *ac* \"currentTime\")))
    (setf (jscl::oget osc \"type\") wave-type)
    ((jscl::oget freq \"setValueAtTime\") freq-start now)
    ((jscl::oget freq \"exponentialRampToValueAtTime\") freq-end (+ now dur))
    ((jscl::oget vol-g \"setValueAtTime\") vol now)
    ((jscl::oget vol-g \"exponentialRampToValueAtTime\") 0.001 (+ now dur))
    ((jscl::oget osc \"connect\") gain)
    ((jscl::oget gain \"connect\") (jscl::oget *ac* \"destination\"))
    ((jscl::oget osc \"start\") now)
    ((jscl::oget osc \"stop\") (+ now dur))))

(defun snd-jump () (play-snd #j\"square\" 300 600 0.1 0.15))
(defun snd-collect () (play-snd #j\"sine\" 800 1200 0.15 0.1))
(defun snd-hit () (play-snd #j\"sawtooth\" 200 50 0.2 0.3))
(defun snd-step () (play-snd #j\"triangle\" 80 60 0.08 0.03))

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
                    :w 20 :h 22 :type :closure :color \"#6b7280\")
             *obstacles*))
      ((= type 1)
       ;; Компилятор — высокое препятствие (нужно прыгнуть)
       (push (list :x (+ *W* 20) :y (- *ground-y* 48)
                   :w 18 :h 40 :type :compiler :color \"#ef4444\")
             *obstacles*))
      (t
       ;; Ловушка — узкое препятствие
       (push (list :x (+ *W* 20) :y (- *ground-y* 20)
                    :w 30 :h 16 :type :trap :color \"#f59e0b\")
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
                       :w 10 :h 22 :color \"#f59e0b\")))

;;; Отрисовка
(defun draw-lambda (x y w h color)
  (setf (jscl::oget *ctx* \"fillStyle\") (jscl/ffi:jsstring color))
  (setf (jscl::oget *ctx* \"textAlign\") #j\"center\")
  ((jscl::oget *ctx* \"fillText\") #j\"λ\" (+ x (/ w 2)) (+ y h -4)))

(defun draw-closure (o)
  (let ((x (getf o :x)) (y (getf o :y))
        (w (getf o :w)) (h (getf o :h))
        (c (getf o :color)))
    (setf (jscl::oget *ctx* \"fillStyle\") (jscl/ffi:jsstring c))
    ((jscl::oget *ctx* \"fillRect\") x y w h)
    (setf (jscl::oget *ctx* \"fillStyle\") #j\"#fff\")
    (setf (jscl::oget *ctx* \"font\") #j\"bold 10px monospace\")
    (setf (jscl::oget *ctx* \"textAlign\") #j\"center\")
    (cond
      ((eq (getf o :type) :closure)
       ((jscl::oget *ctx* \"fillText\") #j\"λ\" (+ x (/ w 2)) (+ y (/ h 2) 3)))
      ((eq (getf o :type) :compiler)
       ((jscl::oget *ctx* \"fillText\") #j\"CC\" (+ x (/ w 2)) (+ y (/ h 2) 3)))
      (t
       ((jscl::oget *ctx* \"fillText\") #j\"//\" (+ x (/ w 2)) (+ y (/ h 2) 3))))))

(defun draw-curry (c)
  (let ((x (getf c :x)) (y (getf c :y)))
    (setf (jscl::oget *ctx* \"fillStyle\") #j\"#fbbf24\")
    ((jscl::oget *ctx* \"beginPath\"))
    ((jscl::oget *ctx* \"arc\") (+ x 8) (+ y 8) 8 0 (* 2 3.14159))
    ((jscl::oget *ctx* \"fill\"))
    (setf (jscl::oget *ctx* \"fillStyle\") #j\"#92400e\")
    (setf (jscl::oget *ctx* \"font\") #j\"bold 10px monospace\")
    (setf (jscl::oget *ctx* \"textAlign\") #j\"center\")
    ((jscl::oget *ctx* \"fillText\") #j\"C\" (+ x 8) (+ y 12))))

(defun draw-particle (p)
  (setf (jscl::oget *ctx* \"fillStyle\") (jscl/ffi:jsstring (getf p :color)))
  ((jscl::oget *ctx* \"fillRect\") (getf p :x) (getf p :y) 3 3))

(defun draw-ground ()
  (setf (jscl::oget *ctx* \"fillStyle\") #j\"#1a1a2e\")
  ((jscl::oget *ctx* \"fillRect\") 0 *ground-y* *W* (- *H* *ground-y*))
  (setf (jscl::oget *ctx* \"fillStyle\") #j\"#2d2d44\")
  ((jscl::oget *ctx* \"fillRect\") 0 *ground-y* *W* 2))

(defun draw-hud ()
  (setf (jscl::oget *ctx* \"fillStyle\") #j\"#fff\")
  (setf (jscl::oget *ctx* \"font\") #j\"14px monospace\")
  (setf (jscl::oget *ctx* \"textAlign\") #j\"left\")
  ((jscl::oget *ctx* \"fillText\") (jscl/ffi:jsstring (format nil \"Score: ~a\" *score*)) 10 24)
  (setf (jscl::oget *ctx* \"textAlign\") #j\"right\")
  ((jscl::oget *ctx* \"fillText\") (jscl/ffi:jsstring (format nil \"Best: ~a\" *high-score*)) (- *W* 10) 24)
  (when *paused*
    (setf (jscl::oget *ctx* \"fillStyle\") #j\"rgba(0,0,0,0.6)\")
    ((jscl::oget *ctx* \"fillRect\") 0 0 *W* *H*)
    (setf (jscl::oget *ctx* \"fillStyle\") #j\"#fff\")
    (setf (jscl::oget *ctx* \"font\") #j\"bold 24px monospace\")
    (setf (jscl::oget *ctx* \"textAlign\") #j\"center\")
    ((jscl::oget *ctx* \"fillText\") #j\"PAUSED\" (/ *W* 2) (/ *H* 2)))
  (when *game-over*
    (setf (jscl::oget *ctx* \"fillStyle\") #j\"rgba(0,0,0,0.7)\")
    ((jscl::oget *ctx* \"fillRect\") 0 0 *W* *H*)
    (setf (jscl::oget *ctx* \"fillStyle\") #j\"#ef4444\")
    (setf (jscl::oget *ctx* \"font\") #j\"bold 28px monospace\")
    (setf (jscl::oget *ctx* \"textAlign\") #j\"center\")
    ((jscl::oget *ctx* \"fillText\") #j\"GAME OVER\" (/ *W* 2) (- (/ *H* 2) 10))
    (setf (jscl::oget *ctx* \"fillStyle\") #j\"#fff\")
    (setf (jscl::oget *ctx* \"font\") #j\"16px monospace\")
    ((jscl::oget *ctx* \"fillText\") (jscl/ffi:jsstring (format nil \"Score: ~a\" *score*)) (/ *W* 2) (+ (/ *H* 2) 20))
    (setf (jscl::oget *ctx* \"fillStyle\") #j\"#888\")
    (setf (jscl::oget *ctx* \"font\") #j\"14px monospace\")
    ((jscl::oget *ctx* \"fillText\") #j\"Press Enter\" (/ *W* 2) (+ (/ *H* 2) 50))))

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
            (spawn-particle (+ cx 8) (+ cy 8) \"#fbbf24\")))))))

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

  (setf (jscl::oget *ctx* \"fillStyle\") #j\"#0a0a0a\")
  ((jscl::oget *ctx* \"fillRect\") 0 0 *W* *H*)

  ;; Звёзды на фоне
  (when (= (mod *tick* 3) 0)
    (setf (jscl::oget *ctx* \"fillStyle\") #j\"#333\")
    ((jscl::oget *ctx* \"fillRect\") (random *W*) (random (- *ground-y* 20)) 1 1))

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
  (setf *ctx* ((jscl::oget (#j:document:getElementById #j\"game-canvas\") \"getContext\") #j\"2d\"))
  (let ((doc #j:document))
    ((jscl::oget doc \"addEventListener\")
     #j\"keydown\"
     (lambda (e)
       (let ((code (jscl::oget e \"keyCode\")))
         (setf (aref *keys* code) 1)
         (when (or (= code 37) (= code 38) (= code 39) (= code 40) (= code 32))
           ((jscl::oget e \"preventDefault\"))))))
    ((jscl::oget doc \"addEventListener\")
     #j\"keyup\"
     (lambda (e)
       (setf (aref *keys* (jscl::oget e \"keyCode\")) 0))))
  (reset))
")
    ("lisp-invaders" "cl" ";;; Lisp Invaders — клон Space Invaders для JSCL
;;; Всё на Common Lisp. Canvas через jscl::oget, строки через #j\"\".

(defpackage :lisp-invaders
  (:use :cl)
  (:import-from :jscl/ffi)
  (:export #:start-lisp-invaders
           #:game-loop-raw))

(in-package :lisp-invaders)

;;; Состояние
(defvar *score* 0)
(defvar *lives* 3)
(defvar *level* 1)
(defvar *game-over* nil)
(defvar *paused* nil)
(defvar *W* 640)
(defvar *H* 480)
(defvar *ctx* nil)
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

;;; Ввод

(defvar *keys* (make-array 256 :initial-element 0))

(defun key-pressed (code)
  (= 1 (aref *keys* code)))

(defvar *input-left* nil)
(defvar *input-right* nil)
(defvar *input-space* nil)
(defvar *pause-clicks* 0)
(defvar *reset-clicks* 0)
(defvar *prev-p* nil)
(defvar *prev-enter* nil)
(defvar *prev-space* nil)
(defvar *shoot-edge* nil)

(defun read-input ()
  (setf *input-left*  (or (key-pressed 37) (key-pressed 65)))
  (setf *input-right* (or (key-pressed 39) (key-pressed 68)))
  (setf *input-space* (key-pressed 32))
  (let ((p-now (key-pressed 80)))
    (when (and p-now (not *prev-p*)) (incf *pause-clicks*))
    (setf *prev-p* p-now))
  (let ((enter-now (key-pressed 13)))
    (when (and enter-now (not *prev-enter*)) (incf *reset-clicks*))
    (setf *prev-enter* enter-now))
  (let ((space-now (key-pressed 32)))
    (when (and space-now (not *prev-space*)) (setf *shoot-edge* t))
    (setf *prev-space* space-now)))

;;; Спавн

(defun spawn ()
  (setf *enemies* nil)
  (let ((et (vector (list :l \"defun\"  :c \"#ef4444\" :p 10)
                    (list :l \"lambda\" :c \"#f59e0b\" :p 15)
                    (list :l \"car\"    :c \"#3b82f6\" :p 20)
                    (list :l \"cdr\"    :c \"#8b5cf6\" :p 20)
                    (list :l \"quote\"  :c \"#ec4899\" :p 25)
                    (list :l \"cons\"   :c \"#14b8a6\" :p 30))))
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
                       :w 40 :h 24 :speed 5 :color \"#22c55e\"))
  (spawn))

;;; Отрисовка

(defun draw-str (s x y &key (f #j\"14px monospace\") (a #j\"left\") (c #j\"#fff\"))
  (setf (jscl::oget *ctx* \"font\") f)
  (setf (jscl::oget *ctx* \"textAlign\") a)
  (setf (jscl::oget *ctx* \"fillStyle\") c)
  ((jscl::oget *ctx* \"fillText\") (jscl/ffi:jsstring s) x y))

(defun draw-player ()
  (let* ((p *player*) (x (getf p :x)) (y (getf p :y))
         (w (getf p :w)) (h (getf p :h)))
    (setf (jscl::oget *ctx* \"fillStyle\") (jscl/ffi:jsstring (getf p :color)))
    ((jscl::oget *ctx* \"beginPath\"))
    ((jscl::oget *ctx* \"moveTo\") x (+ y h))
    ((jscl::oget *ctx* \"lineTo\") (+ x (/ w 2)) y)
    ((jscl::oget *ctx* \"lineTo\") (+ x w) (+ y h))
    ((jscl::oget *ctx* \"closePath\"))
    ((jscl::oget *ctx* \"fill\"))
    (draw-str #j\"defun\" (+ x (/ w 2)) (- (+ y h) 6)
              :f #j\"bold 9px monospace\" :a #j\"center\" :c #j\"#000\")))

(defun draw-enemies ()
  (dolist (e *enemies*)
    (when (getf e :alive)
      (let* ((x (getf e :x)) (y (getf e :y))
             (w (getf e :w)) (h (getf e :h))
             (tp (getf e :type))
             (color (getf tp :c)) (label (getf tp :l)))
        (setf (jscl::oget *ctx* \"fillStyle\") (jscl/ffi:jsstring color))
        ((jscl::oget *ctx* \"fillRect\") x y w h)
        (setf (jscl::oget *ctx* \"fillStyle\") #j\"#000\")
        ((jscl::oget *ctx* \"fillRect\") (+ x 10) (+ y 8) 6 6)
        ((jscl::oget *ctx* \"fillRect\") (+ x w -16) (+ y 8) 6 6)
        (setf (jscl::oget *ctx* \"fillStyle\") (jscl/ffi:jsstring color))
        ((jscl::oget *ctx* \"fillRect\") (+ x 12) (+ y 10) 2 2)
        ((jscl::oget *ctx* \"fillRect\") (+ x w -14) (+ y 10) 2 2)
        (incf (getf e :f) 0.05)
        (let ((off (if (> (mod (getf e :f) 2.0) 1.0) 2.5 -2.5)))
          ((jscl::oget *ctx* \"fillRect\") (+ x 6) (+ y h) 4 (+ 4 off))
          ((jscl::oget *ctx* \"fillRect\") (+ x w -10) (+ y h) 4 (- 4 off)))
        (draw-str label (+ x (/ w 2)) (+ y (/ h 2) 3)
                  :f #j\"bold 8px monospace\" :a #j\"center\" :c #j\"#000\")))))

(defun draw-bullets ()
  (setf (jscl::oget *ctx* \"fillStyle\") #j\"#22c55e\")
  (dolist (b *bullets*)
    ((jscl::oget *ctx* \"fillRect\") (- (getf b :x) 2) (getf b :y) 4 12))
  (setf (jscl::oget *ctx* \"fillStyle\") #j\"#ef4444\")
  (dolist (b *enemy-bullets*)
    ((jscl::oget *ctx* \"fillRect\") (- (getf b :x) 1) (getf b :y) 3 8)))

(defun draw-hud ()
  (draw-str (format nil \"Score: ~a\" *score*) 10 24
            :f #j\"bold 16px monospace\" :c #j\"#22c55e\")
  (loop for i below *lives*
        do (draw-str \"X\" (- *W* 10 (* i 22)) 24
                     :f #j\"bold 16px monospace\" :a #j\"right\" :c #j\"#ef4444\"))
  (draw-str (format nil \"Level ~a\" *level*) (/ *W* 2) 24
            :f #j\"12px monospace\" :a #j\"center\" :c #j\"#888\")
  (when *paused*
    (setf (jscl::oget *ctx* \"fillStyle\") #j\"rgba(0,0,0,0.6)\")
    ((jscl::oget *ctx* \"fillRect\") 0 0 *W* *H*)
    (draw-str \"PAUSED\" (/ *W* 2) (/ *H* 2)
              :f #j\"bold 24px monospace\" :a #j\"center\"))
  (when *game-over*
    (setf (jscl::oget *ctx* \"fillStyle\") #j\"rgba(0,0,0,0.7)\")
    ((jscl::oget *ctx* \"fillRect\") 0 0 *W* *H*)
    (draw-str \"GAME OVER\" (/ *W* 2) (- (/ *H* 2) 10)
              :f #j\"bold 28px monospace\" :a #j\"center\" :c #j\"#ef4444\")
    (draw-str (format nil \"Score: ~a\" *score*) (/ *W* 2) (+ (/ *H* 2) 20)
              :f #j\"16px monospace\" :a #j\"center\")
    (draw-str \"Press Enter\" (/ *W* 2) (+ (/ *H* 2) 50)
              :f #j\"14px monospace\" :a #j\"center\" :c #j\"#888\")))

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

;;; Звук

(defvar *ac* nil)

(defun ensure-audio-ctx ()
  (unless *ac*
    (setf *ac* (#j:Reflect:construct (or #j:AudioContext #j:webkitAudioContext) (#j:Array)))))

(defun play-snd (wave-type freq-start freq-end vol dur)
  (ensure-audio-ctx)
  (let* ((osc ((jscl::oget *ac* \"createOscillator\")))
         (gain ((jscl::oget *ac* \"createGain\")))
         (freq (jscl::oget osc \"frequency\"))
         (vol-g (jscl::oget gain \"gain\"))
         (now (jscl::oget *ac* \"currentTime\")))
    (setf (jscl::oget osc \"type\") wave-type)
    ((jscl::oget freq \"setValueAtTime\") freq-start now)
    ((jscl::oget freq \"exponentialRampToValueAtTime\") freq-end (+ now dur))
    ((jscl::oget vol-g \"setValueAtTime\") vol now)
    ((jscl::oget vol-g \"exponentialRampToValueAtTime\") 0.001 (+ now dur))
    ((jscl::oget osc \"connect\") gain)
    ((jscl::oget gain \"connect\") (jscl::oget *ac* \"destination\"))
    ((jscl::oget osc \"start\") now)
    ((jscl::oget osc \"stop\") (+ now dur))))

(defun snd-shoot () (play-snd #j\"square\" 880 440 0.15 0.1))
(defun snd-hit () (play-snd #j\"sawtooth\" 300 50 0.2 0.2))
(defun snd-hurt () (play-snd #j\"sawtooth\" 200 80 0.2 0.3))
(defun snd-over () (play-snd #j\"square\" 440 55 0.15 0.8))

;;; Состояние для отслеживания изменений (для звука)
(defvar *prev-score* 0)
(defvar *prev-lives* 3)
(defvar *prev-over* nil)

;;; Игровой цикл

(defun game-loop-raw ()
  (setf *prev-score* *score*)
  (setf *prev-lives* *lives*)
  (setf *prev-over* *game-over*)
  (read-input)
  (when (plusp *pause-clicks*)
    (setf *pause-clicks* 0)
    (setf *paused* (not *paused*)))
  (when (plusp *reset-clicks*)
    (setf *reset-clicks* 0)
    (when *game-over* (reset)))
  (setf (jscl::oget *ctx* \"fillStyle\") #j\"#0a0a0a\")
  ((jscl::oget *ctx* \"fillRect\") 0 0 *W* *H*)
  (update)
  (draw-player)
  (draw-enemies)
  (draw-bullets)
  (draw-hud)
  (when (and (not *prev-over*) *game-over*) (snd-over))
  (when (> *prev-lives* *lives*) (snd-hurt))
  (when (> *score* *prev-score*) (snd-hit))
  (when (and *shoot-edge* (not *game-over*) (not *paused*))
    (snd-shoot))
  (setf *shoot-edge* nil))

;;; Точка входа

(defun start-lisp-invaders ()
  (setf *ctx* ((jscl::oget (#j:document:getElementById #j\"game-canvas\") \"getContext\") #j\"2d\"))
  (let ((doc #j:document))
    ((jscl::oget doc \"addEventListener\")
     #j\"keydown\"
     (lambda (e)
       (let ((code (jscl::oget e \"keyCode\")))
         (setf (aref *keys* code) 1)
         (when (or (= code 37) (= code 38) (= code 39) (= code 40) (= code 32))
           ((jscl::oget e \"preventDefault\"))))))
    ((jscl::oget doc \"addEventListener\")
     #j\"keyup\"
     (lambda (e)
       (setf (aref *keys* (jscl::oget e \"keyCode\")) 0))))
  (reset))
")
    ("paren-matcher" "cl" ";;; Paren Matcher — игра на сопоставление скобок для JSCL
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
  (list (cons \"(\" \")\")
        (cons \"[\" \"]\")
        (cons \"{\" \"}\")))

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
    ((or (string= s \"(\") (string= s \")\")) \"#3b82f6\")
    ((or (string= s \"[\") (string= s \"]\")) \"#22c55e\")
    ((or (string= s \"{\") (string= s \"}\")) \"#eab308\")
    (t \"#fff\")))

;;; Спавн
(defun spawn-bracket ()
  (snd-spawn)
  (let* ((types '(\"(\" \")\" \"[\" \"]\" \"{\" \"}\"))
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
                       :w 60 :h 12 :color \"#3b82f6\")))

;;; Отрисовка
(defun draw-player ()
  (let ((x (getf *player* :x)) (y (getf *player* :y))
        (w (getf *player* :w)) (h (getf *player* :h)))
    (setf (jscl::oget *ctx* \"fillStyle\") (jscl/ffi:jsstring (getf *player* :color)))
    ((jscl::oget *ctx* \"fillRect\") x y w h)
    (setf (jscl::oget *ctx* \"fillStyle\") #j\"#fff\")
    (setf (jscl::oget *ctx* \"font\") #j\"bold 10px monospace\")
    (setf (jscl::oget *ctx* \"textAlign\") #j\"center\")
    ((jscl::oget *ctx* \"fillText\") #j\"()\" (+ x (/ w 2)) (- y 4))))

(defun draw-bracket (b)
  (let ((x (getf b :x)) (y (getf b :y)) (s (getf b :s)))
    (setf (jscl::oget *ctx* \"fillStyle\") (jscl/ffi:jsstring (bracket-color s)))
    (setf (jscl::oget *ctx* \"font\") #j\"bold 24px monospace\")
    (setf (jscl::oget *ctx* \"textAlign\") #j\"center\")
    ((jscl::oget *ctx* \"fillText\") (jscl/ffi:jsstring s) x (+ y 20))))

(defun draw-stack ()
  (let ((sx (- *W* 10)) (sy 50))
    (setf (jscl::oget *ctx* \"fillStyle\") #j\"#555\")
    (setf (jscl::oget *ctx* \"font\") #j\"12px monospace\")
    (setf (jscl::oget *ctx* \"textAlign\") #j\"right\")
    ((jscl::oget *ctx* \"fillText\") (jscl/ffi:jsstring (format nil \"Stack (~a):\" (length *stack*))) sx sy)
    (let ((cx (- *W* 30)))
      (setf (jscl::oget *ctx* \"textAlign\") #j\"center\")
      (dolist (s *stack*)
        (setf (jscl::oget *ctx* \"fillStyle\") (jscl/ffi:jsstring (bracket-color s)))
        (setf (jscl::oget *ctx* \"font\") #j\"bold 18px monospace\")
        ((jscl::oget *ctx* \"fillText\") (jscl/ffi:jsstring s) cx (+ sy 20))
        (decf cx 22)))))

(defun draw-particle (p)
  (setf (jscl::oget *ctx* \"fillStyle\") (jscl/ffi:jsstring (getf p :color)))
  ((jscl::oget *ctx* \"fillRect\") (getf p :x) (getf p :y) 3 3))

(defun draw-float (f)
  (setf (jscl::oget *ctx* \"fillStyle\") (jscl/ffi:jsstring (getf f :color)))
  (setf (jscl::oget *ctx* \"font\") #j\"bold 16px monospace\")
  (setf (jscl::oget *ctx* \"textAlign\") #j\"center\")
  ((jscl::oget *ctx* \"fillText\") (jscl/ffi:jsstring (getf f :text)) (getf f :x) (getf f :y))
  (decf (getf f :y) 1.0))

(defun draw-hud ()
  (setf (jscl::oget *ctx* \"fillStyle\") #j\"#fff\")
  (setf (jscl::oget *ctx* \"font\") #j\"14px monospace\")
  (setf (jscl::oget *ctx* \"textAlign\") #j\"left\")
  ((jscl::oget *ctx* \"fillText\") (jscl/ffi:jsstring (format nil \"Score: ~a\" *score*)) 10 24)
  (setf (jscl::oget *ctx* \"textAlign\") #j\"right\")
  ((jscl::oget *ctx* \"fillText\") (jscl/ffi:jsstring (format nil \"Best: ~a\" *high-score*)) (- *W* 10) 24)
  (setf (jscl::oget *ctx* \"textAlign\") #j\"center\")
  ((jscl::oget *ctx* \"fillText\") (jscl/ffi:jsstring (format nil \"Level: ~a\" *level*)) (/ *W* 2) 24)
  ;; Lives
  (setf (jscl::oget *ctx* \"fillStyle\") #j\"#ef4444\")
  (setf (jscl::oget *ctx* \"font\") #j\"16px monospace\")
  (setf (jscl::oget *ctx* \"textAlign\") #j\"left\")
  (let ((lx 10) (ly (+ *H* -15)))
    (dotimes (i *lives*)
      ((jscl::oget *ctx* \"fillText\") #j\"♥\" (+ lx (* i 20)) ly)))
  ;; Streak
  (when (>= *streak* 2)
    (setf (jscl::oget *ctx* \"fillStyle\") #j\"#22c55e\")
    (setf (jscl::oget *ctx* \"font\") #j\"12px monospace\")
    (setf (jscl::oget *ctx* \"textAlign\") #j\"left\")
    ((jscl::oget *ctx* \"fillText\")
     (jscl/ffi:jsstring (format nil \"Streak: ~a (next heal: ~a)\" *streak* (- 2 (mod *streak* 2))))
     10 (+ *H* -30)))
  ;; Stack overflow warning
  (when (>= (length *stack*) 4)
    (setf (jscl::oget *ctx* \"fillStyle\")
          (if (>= (length *stack*) 5) #j\"#ef4444\" #j\"#f59e0b\"))
    (setf (jscl::oget *ctx* \"font\") #j\"bold 14px monospace\")
    (setf (jscl::oget *ctx* \"textAlign\") #j\"center\")
    ((jscl::oget *ctx* \"fillText\")
     (jscl/ffi:jsstring (format nil \"Stack: ~a/6\" (length *stack*)))
     (/ *W* 2) (+ *H* -15)))
  ;; Paused
  (when *paused*
    (setf (jscl::oget *ctx* \"fillStyle\") #j\"rgba(0,0,0,0.6)\")
    ((jscl::oget *ctx* \"fillRect\") 0 0 *W* *H*)
    (setf (jscl::oget *ctx* \"fillStyle\") #j\"#fff\")
    (setf (jscl::oget *ctx* \"font\") #j\"bold 24px monospace\")
    (setf (jscl::oget *ctx* \"textAlign\") #j\"center\")
    ((jscl::oget *ctx* \"fillText\") #j\"PAUSED\" (/ *W* 2) (/ *H* 2)))
  ;; Game over
  (when *game-over*
    (setf (jscl::oget *ctx* \"fillStyle\") #j\"rgba(0,0,0,0.7)\")
    ((jscl::oget *ctx* \"fillRect\") 0 0 *W* *H*)
    (setf (jscl::oget *ctx* \"fillStyle\") #j\"#ef4444\")
    (setf (jscl::oget *ctx* \"font\") #j\"bold 28px monospace\")
    (setf (jscl::oget *ctx* \"textAlign\") #j\"center\")
    ((jscl::oget *ctx* \"fillText\") #j\"GAME OVER\" (/ *W* 2) (- (/ *H* 2) 10))
    (setf (jscl::oget *ctx* \"fillStyle\") #j\"#fff\")
    (setf (jscl::oget *ctx* \"font\") #j\"16px monospace\")
    ((jscl::oget *ctx* \"fillText\") (jscl/ffi:jsstring (format nil \"Score: ~a\" *score*)) (/ *W* 2) (+ (/ *H* 2) 20))
    (setf (jscl::oget *ctx* \"fillStyle\") #j\"#888\")
    (setf (jscl::oget *ctx* \"font\") #j\"14px monospace\")
    ((jscl::oget *ctx* \"fillText\") #j\"Press Enter\" (/ *W* 2) (+ (/ *H* 2) 50))))

;;; Звук
(defvar *ac* nil)

(defun ensure-audio-ctx ()
  (unless *ac*
    (setf *ac* (#j:Reflect:construct (or #j:AudioContext #j:webkitAudioContext) (#j:Array)))))

(defun play-snd (wave-type freq-start freq-end vol dur)
  (ensure-audio-ctx)
  (let* ((osc ((jscl::oget *ac* \"createOscillator\")))
         (gain ((jscl::oget *ac* \"createGain\")))
         (freq (jscl::oget osc \"frequency\"))
         (vol-g (jscl::oget gain \"gain\"))
         (now (jscl::oget *ac* \"currentTime\")))
    (setf (jscl::oget osc \"type\") wave-type)
    ((jscl::oget freq \"setValueAtTime\") freq-start now)
    ((jscl::oget freq \"exponentialRampToValueAtTime\") freq-end (+ now dur))
    ((jscl::oget vol-g \"setValueAtTime\") vol now)
    ((jscl::oget vol-g \"exponentialRampToValueAtTime\") 0.001 (+ now dur))
    ((jscl::oget osc \"connect\") gain)
    ((jscl::oget gain \"connect\") (jscl::oget *ac* \"destination\"))
    ((jscl::oget osc \"start\") now)
    ((jscl::oget osc \"stop\") (+ now dur))))

(defun snd-match () (play-snd #j\"sine\" 600 1200 0.15 0.1))
(defun snd-catch () (play-snd #j\"triangle\" 400 600 0.1 0.08))
(defun snd-miss () (play-snd #j\"sawtooth\" 300 100 0.2 0.2))
(defun snd-overflow () (play-snd #j\"square\" 200 50 0.25 0.4))
(defun snd-levelup () (play-snd #j\"sine\" 400 800 0.1 0.3))
(defun snd-spawn () (play-snd #j\"sine\" 1200 800 0.05 0.05))

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
          (spawn-float (getf b :x) (- *H* 30) \"-1 ♥\" \"#ef4444\")
          (when (<= *lives* 0)
            (setf *game-over* t)
            (when (> *score* *high-score*) (setf *high-score* *score*))))
         ;; Открывающая улетела при пустом стеке — тоже штраф
         ((and (open-paren-p s)
               (not *stack*))
          (setf *streak* 0)
          (decf *lives*)
          (snd-miss)
          (spawn-float (getf b :x) (- *H* 30) \"-1 ♥\" \"#ef4444\")
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
                          (spawn-particle bx (- by 10) \"#22c55e\")
                          (spawn-particle bx (- by 20) \"#22c55e\")
                          (when (> mult 1)
                            (spawn-float bx (- by 30) (format nil \"~ax!\" mult) \"#eab308\"))
                          ;; Хил каждые 2 стрика
                          (when (and (>= *streak* 2) (= (mod *streak* 2) 0)
                                     (< *lives* *max-lives*))
                            (incf *lives*)
                            (snd-levelup)
                            (spawn-float bx (- by 50) \"+1 ♥\" \"#3b82f6\")
                            (spawn-particle bx (- by 50) \"#3b82f6\")
                            (spawn-particle bx (- by 60) \"#3b82f6\"))
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
                         (spawn-float bx (- by 20) \"-1 ♥\" \"#ef4444\")
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

  (setf (jscl::oget *ctx* \"fillStyle\") #j\"#0a0a0a\")
  ((jscl::oget *ctx* \"fillRect\") 0 0 *W* *H*)

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
  (setf *ctx* ((jscl::oget (#j:document:getElementById #j\"game-canvas\") \"getContext\") #j\"2d\"))
  (let ((doc #j:document))
    ((jscl::oget doc \"addEventListener\")
     #j\"keydown\"
     (lambda (e)
       (let ((code (jscl::oget e \"keyCode\")))
         (setf (aref *keys* code) 1)
         (when (or (= code 37) (= code 38) (= code 39) (= code 40) (= code 32))
           ((jscl::oget e \"preventDefault\"))))))
    ((jscl::oget doc \"addEventListener\")
     #j\"keyup\"
     (lambda (e)
       (setf (aref *keys* (jscl::oget e \"keyCode\")) 0))))
  (reset))
")
    ("s-dungeon" "cl" ";;; S-Expression Dungeon — roguelike для JSCL
;;; Пошаговое подземелье: герой-интерпретатор, враги-баги, лут-макросы.

(defpackage :s-dungeon
  (:use :cl)
  (:import-from :jscl/ffi)
  (:export #:start-s-dungeon
           #:game-loop-raw))

(in-package :s-dungeon)

;;; Константы
(defvar *tile* 20)
(defvar *mw* 80)
(defvar *mh* 50)
(defvar *W* 640)
(defvar *H* 480)

;;; Состояние
(defvar *ctx* nil)
(defvar *map* nil)
(defvar *rooms* nil)
(defvar *player* nil)
(defvar *enemies* nil)
(defvar *items* nil)
(defvar *msgs* nil)
(defvar *turn* 0)
(defvar *game-over* nil)
(defvar *game-won* nil)
(defvar *score* 0)
(defvar *high-score* 0)
(defvar *floor* 1)

;;; Клавиатура
(defvar *keys* (make-array 256 :initial-element 0))
(defvar *prev-keys* (make-array 256 :initial-element 0))
(defvar *key-timer* (make-array 256 :initial-element 0))
(defvar *act* nil)

(defun key-just-pressed (code)
  (and (= 1 (aref *keys* code)) (= 0 (aref *prev-keys* code))))

(defun key-held-repeat (code delay)
  (let ((now (#j:Date:now)))
    (if (= 1 (aref *keys* code))
        (if (= 0 (aref *prev-keys* code))
            (progn (setf (aref *key-timer* code) now) t)
            (when (> (- now (aref *key-timer* code)) delay)
              (setf (aref *key-timer* code) now)
              t))
        nil)))

(defun save-key-state ()
  (dotimes (i 256)
    (setf (aref *prev-keys* i) (aref *keys* i))))

;;; Звук
(defvar *ac* nil)

(defun ensure-audio-ctx ()
  (unless *ac*
    (setf *ac* (#j:Reflect:construct (or #j:AudioContext #j:webkitAudioContext) (#j:Array)))))

(defun play-snd (wave fe te vol dur)
  (ensure-audio-ctx)
  (let* ((o ((jscl::oget *ac* \"createOscillator\")))
         (g ((jscl::oget *ac* \"createGain\")))
         (f (jscl::oget o \"frequency\"))
         (vg (jscl::oget g \"gain\"))
         (n (jscl::oget *ac* \"currentTime\")))
    (setf (jscl::oget o \"type\") wave)
    ((jscl::oget f \"setValueAtTime\") fe n)
    ((jscl::oget f \"exponentialRampToValueAtTime\") te (+ n dur))
    ((jscl::oget vg \"setValueAtTime\") vol n)
    ((jscl::oget vg \"exponentialRampToValueAtTime\") 0.001 (+ n dur))
    ((jscl::oget o \"connect\") g)
    ((jscl::oget g \"connect\") (jscl::oget *ac* \"destination\"))
    ((jscl::oget o \"start\") n)
    ((jscl::oget o \"stop\") (+ n dur))))

(defun snd-step () (play-snd #j\"triangle\" 200 100 0.04 0.04))
(defun snd-hit () (play-snd #j\"sawtooth\" 300 100 0.12 0.12))
(defun snd-hurt () (play-snd #j\"square\" 200 50 0.15 0.15))
(defun snd-pickup () (play-snd #j\"sine\" 600 1200 0.1 0.1))
(defun snd-stairs () (play-snd #j\"sine\" 400 800 0.12 0.3))
(defun snd-kill () (play-snd #j\"sawtooth\" 400 200 0.1 0.2))
(defun snd-die () (play-snd #j\"square\" 300 50 0.2 0.5))
(defun snd-levelup () (play-snd #j\"sine\" 400 800 0.1 0.3))

;;; Генерация подземелья
(defun make-room (x y w h)
  (list :x x :y y :w w :h h))

(defun room-center (r)
  (cons (+ (getf r :x) (floor (getf r :w) 2))
        (+ (getf r :y) (floor (getf r :h) 2))))

(defun rooms-overlap (a b)
  (and (< (getf a :x) (+ (getf b :x) (getf b :w)))
       (> (+ (getf a :x) (getf a :w)) (getf b :x))
       (< (getf a :y) (+ (getf b :y) (getf b :h)))
       (> (+ (getf a :y) (getf a :h)) (getf b :y))))

(defun in-bounds (x y)
  (and (>= x 0) (< x *mw*) (>= y 0) (< y *mh*)))

(defun tile (x y)
  (if (in-bounds x y) (aref *map* y x) 0))

(defun set-tile (x y v)
  (when (in-bounds x y) (setf (aref *map* y x) v)))

(defun generate-dungeon ()
  (setf *map* (make-array (list *mh* *mw*) :initial-element 0))
  (setf *rooms* nil)
  (dotimes (i 200)
    (when (< (length *rooms*) (+ 5 (random 5)))
      (let* ((w (+ 4 (random 6))) (h (+ 3 (random 4)))
             (x (+ 1 (random (- *mw* w 2))))
             (y (+ 1 (random (- *mh* h 2))))
             (r (make-room x y w h)))
        (when (not (some (lambda (o) (rooms-overlap o r)) *rooms*))
          (dotimes (dy h) (dotimes (dx w) (set-tile (+ x dx) (+ y dy) 1)))
          (push r *rooms*)))))
  ;; Коридоры
  (let ((conn (list (car *rooms*))))
    (dolist (r (cdr *rooms*))
      (let* ((prev (car (last conn)))
             (c1 (room-center prev)) (c2 (room-center r))
             (x1 (car c1)) (y1 (cdr c1))
             (x2 (car c2)) (y2 (cdr c2)))
        (do ((x (min x1 x2) (1+ x))) ((> x (max x1 x2)))
          (set-tile x y1 1))
        (do ((y (min y1 y2) (1+ y))) ((> y (max y1 y2)))
          (set-tile x2 y 1)))
      (push r conn))))

(defun place-stairs ()
  (when *rooms*
    (let ((c (room-center (car (last *rooms*)))))
      (set-tile (car c) (cdr c) 3))))

(defun place-enemies ()
  (setf *enemies* nil)
  (let ((types (list (list :name \"void-fn\" :hp 3 :dmg 1 :xp 10 :sym \"V\" :col \"#ef4444\")
                     (list :name \"wrong-type\" :hp 4 :dmg 2 :xp 15 :sym \"W\" :col \"#f97316\")
                     (list :name \"unbound\" :hp 2 :dmg 1 :xp 8 :sym \"U\" :col \"#eab308\")
                     (list :name \"overflow\" :hp 6 :dmg 3 :xp 25 :sym \"O\" :col \"#dc2626\")
                     (list :name \"null-ref\" :hp 3 :dmg 2 :xp 12 :sym \"N\" :col \"#a855f7\"))))
    (dolist (room (cdr *rooms*))
      (let ((c (room-center room)))
        (dotimes (i (+ 1 (random 2)))
          (let* ((tp (nth (random (length types)) types))
                 (rx (+ (getf room :x) 1 (random (max 1 (- (getf room :w) 2)))))
                 (ry (+ (getf room :y) 1 (random (max 1 (- (getf room :h) 2))))))
            (when (and (= 1 (tile rx ry))
                       (not (some (lambda (e) (and (= (getf e :x) rx) (= (getf e :y) ry))) *enemies*))
                       (not (and (= rx (car c)) (= ry (cdr c)))))
              (push (append (list :x rx :y ry :hp (getf tp :hp) :max-hp (getf tp :hp)) tp)
                    *enemies*))))))))

(defun place-items ()
  (setf *items* nil)
  (let ((types (list (list :name \"defun\" :kind :heal :val 3 :col \"#22c55e\" :sym \"λ\")
                     (list :name \"defmacro\" :kind :maxhp :val 1 :col \"#3b82f6\" :sym \"M\")
                     (list :name \"setf\" :kind :dmg :val 1 :col \"#a855f7\" :sym \"=\")
                     (list :name \"progn\" :kind :heal :val 6 :col \"#10b981\" :sym \"+\"))))
    (dolist (room (cdr *rooms*))
      (when (< (random 3) 1)
        (let* ((tp (nth (random (length types)) types))
               (rx (+ (getf room :x) 1 (random (max 1 (- (getf room :w) 2)))))
               (ry (+ (getf room :y) 1 (random (max 1 (- (getf room :h) 2))))))
          (when (= 1 (tile rx ry))
            (push (append (list :x rx :y ry) tp) *items*)))))))

(defun reset-player ()
  (let ((c (room-center (car *rooms*))))
    (setf (getf *player* :x) (car c)
          (getf *player* :y) (cdr c))))

;;; Сообщения
(defun add-msg (text col)
  (push (list :text text :color col :life 80) *msgs*)
  (when (> (length *msgs*) 4)
    (setf *msgs* (subseq *msgs* 0 4))))

;;; Инициализация уровня/игры
(defun init-level ()
  (generate-dungeon) (place-stairs) (place-enemies) (place-items) (reset-player)
  (setf *msgs* nil *turn* 0)
  (add-msg (format nil \"Floor ~a. Find >\" *floor*) \"#888\"))

(defun reset-game ()
  (setf *floor* 1 *game-over* nil *game-won* nil *score* 0)
  (setf *player* nil)
  (init-level)
  (setf (getf *player* :hp) 15
        (getf *player* :max-hp) 15
        (getf *player* :dmg) 2
        (getf *player* :level) 1
        (getf *player* :xp) 0))

;;; Логика
(defun walkable (x y) (> (tile x y) 0))

(defun enemy-at (x y)
  (find-if (lambda (e) (and (= (getf e :x) x) (= (getf e :y) y))) *enemies*))

(defun item-at (x y)
  (find-if (lambda (i) (and (= (getf i :x) x) (= (getf i :y) y))) *items*))

(defun try-move (dx dy)
  (let* ((nx (+ (getf *player* :x) dx))
         (ny (+ (getf *player* :y) dy))
         (en (enemy-at nx ny)))
    (cond
     ;; Враг — атака
     (en
      (let ((d (getf *player* :dmg)))
        (decf (getf en :hp) d)
        (snd-hit)
        (add-msg (format nil \"Hit ~a (-~a)\" (getf en :name) d) \"#fff\")
        (when (<= (getf en :hp) 0)
          (snd-kill)
          (add-msg (format nil \"Destroyed ~a!\" (getf en :name)) \"#22c55e\")
          (incf *score* (getf en :xp))
          (incf (getf *player* :xp) (getf en :xp))
          (setf *enemies* (remove en *enemies*))
          (when (>= (getf *player* :xp) (* (getf *player* :level) 20))
            (incf (getf *player* :level))
            (incf (getf *player* :max-hp) 2)
            (incf (getf *player* :hp) 2)
            (incf (getf *player* :dmg))
            (snd-levelup)
            (add-msg (format nil \"Level ~a!\" (getf *player* :level)) \"#eab308\")))))
     ;; Стена
     ((= (tile nx ny) 0) nil)
     ;; Лестница
     ((= (tile nx ny) 3)
      (incf *floor*)
      (snd-stairs)
      (add-msg (format nil \"Floor ~a...\" *floor*) \"#3b82f6\")
      (init-level))
     ;; Предмет
     ((item-at nx ny)
      (let ((it (item-at nx ny)))
        (snd-pickup)
        (case (getf it :kind)
          (:heal
           (incf (getf *player* :hp) (getf it :val))
           (when (> (getf *player* :hp) (getf *player* :max-hp))
             (setf (getf *player* :hp) (getf *player* :max-hp)))
           (add-msg (format nil \"+~a HP\" (getf it :val)) \"#22c55e\"))
          (:maxhp
           (incf (getf *player* :max-hp) (getf it :val))
           (incf (getf *player* :hp) (getf it :val))
           (add-msg (format nil \"+~a max HP\" (getf it :val)) \"#3b82f6\"))
          (:dmg
           (incf (getf *player* :dmg) (getf it :val))
           (add-msg (format nil \"+~a dmg\" (getf it :val)) \"#a855f7\")))
        (setf *items* (remove it *items*))
        (setf (getf *player* :x) nx (getf *player* :y) ny)))
     ;; Ход
     (t
      (setf (getf *player* :x) nx (getf *player* :y) ny)
      (snd-step)))))

(defun move-enemies ()
  (dolist (e *enemies*)
    (let ((px (getf *player* :x)) (py (getf *player* :y))
          (ex (getf e :x)) (ey (getf e :y)))
      (let ((dx (cond ((< px ex) -1) ((> px ex) 1) (t 0)))
            (dy (cond ((< py ey) -1) ((> py ey) 1) (t 0))))
        (let ((nx (+ ex dx)) (ny (+ ey dy)))
          (cond
           ((and (= nx px) (= ny py))
            (decf (getf *player* :hp) (getf e :dmg))
            (snd-hurt)
            (add-msg (format nil \"~a -~a HP\" (getf e :name) (getf e :dmg)) \"#ef4444\")
            (when (<= (getf *player* :hp) 0)
              (setf (getf *player* :hp) 0 *game-over* t)
              (snd-die)
              (when (> *score* *high-score*) (setf *high-score* *score*))))
           ((and (walkable nx ny)
                 (not (enemy-at nx ny)))
            (setf (getf e :x) nx (getf e :y) ny))
           (t
            (let ((nx2 ex) (ny2 (+ ey dy)))
              (when (and (walkable nx2 ny2) (not (enemy-at nx2 ny2)))
                (setf (getf e :x) nx2 (getf e :y) ny2))))))))))

;;; Ввод
(defun read-input ()
  (setf *act* nil)
  (cond
   ((or (key-held-repeat 37 100) (key-held-repeat 65 100)) (setf *act* :l))
   ((or (key-held-repeat 38 100) (key-held-repeat 87 100)) (setf *act* :u))
   ((or (key-held-repeat 39 100) (key-held-repeat 68 100)) (setf *act* :r))
   ((or (key-held-repeat 40 100) (key-held-repeat 83 100)) (setf *act* :d))
   ((key-just-pressed 190) (setf *act* :wait))))

(defun process-action ()
  (when *act*
    (case *act*
      (:l (try-move -1 0))
      (:r (try-move 1 0))
      (:u (try-move 0 -1))
      (:d (try-move 0 1))
      (:wait (snd-step)))
    (when (and *act* (not *game-over*))
      (move-enemies))
    (setf *act* nil)))

;;; Отрисовка
(defun map-to-sx (mx)
  (+ (* (- mx (getf *player* :x)) *tile*) (floor *W* 2)))

(defun map-to-sy (my)
  (+ (* (- my (getf *player* :y)) *tile*) (floor (- *H* 30) 2)))

(defun draw-tiles ()
  (let* ((px (getf *player* :x)) (py (getf *player* :y))
         (half-x (ceiling *W* (* 2 *tile*)))
         (half-y (ceiling (- *H* 30) (* 2 *tile*)))
         (x0 (max 0 (- px half-x 1)))
         (y0 (max 0 (- py half-y 1)))
         (x1 (min *mw* (+ px half-x 2)))
         (y1 (min *mh* (+ py half-y 2))))
    (dotimes (my (- y1 y0))
      (dotimes (mx (- x1 x0))
        (let* ((tx (+ x0 mx)) (ty (+ y0 my))
               (sx (map-to-sx tx)) (sy (map-to-sy ty)))
          (case (tile tx ty)
            (0
             (setf (jscl::oget *ctx* \"fillStyle\") #j\"#111520\")
             ((jscl::oget *ctx* \"fillRect\") sx sy *tile* *tile*)
             (setf (jscl::oget *ctx* \"fillStyle\") #j\"#1e2233\")
             ((jscl::oget *ctx* \"fillRect\") sx sy *tile* 1)
             ((jscl::oget *ctx* \"fillRect\") sx sy 1 *tile*))
            (1
             (setf (jscl::oget *ctx* \"fillStyle\") #j\"#0d1117\")
             ((jscl::oget *ctx* \"fillRect\") sx sy *tile* *tile*))
            (3
             (setf (jscl::oget *ctx* \"fillStyle\") #j\"#0d1117\")
             ((jscl::oget *ctx* \"fillRect\") sx sy *tile* *tile*)
             (setf (jscl::oget *ctx* \"fillStyle\") #j\"#fbbf24\")
             (setf (jscl::oget *ctx* \"font\") #j\"bold 16px monospace\")
             (setf (jscl::oget *ctx* \"textAlign\") #j\"center\")
             ((jscl::oget *ctx* \"fillText\") #j\">\" (+ sx 10) (+ sy 16)))))))))

(defun draw-items ()
  (dolist (it *items*)
    (let ((sx (map-to-sx (getf it :x))) (sy (map-to-sy (getf it :y))))
      (setf (jscl::oget *ctx* \"fillStyle\") (jscl/ffi:jsstring (getf it :col)))
      (setf (jscl::oget *ctx* \"font\") #j\"bold 14px monospace\")
      (setf (jscl::oget *ctx* \"textAlign\") #j\"center\")
      ((jscl::oget *ctx* \"fillText\") (jscl/ffi:jsstring (getf it :sym)) (+ sx 10) (+ sy 16)))))

(defun draw-enemies ()
  (dolist (e *enemies*)
    (let ((sx (map-to-sx (getf e :x))) (sy (map-to-sy (getf e :y))))
      (setf (jscl::oget *ctx* \"fillStyle\") (jscl/ffi:jsstring (getf e :col)))
      (setf (jscl::oget *ctx* \"font\") #j\"bold 14px monospace\")
      (setf (jscl::oget *ctx* \"textAlign\") #j\"center\")
      ((jscl::oget *ctx* \"fillText\") (jscl/ffi:jsstring (getf e :sym)) (+ sx 10) (+ sy 16)))))

(defun draw-player ()
  (let ((sx (map-to-sx (getf *player* :x))) (sy (map-to-sy (getf *player* :y))))
    (setf (jscl::oget *ctx* \"fillStyle\") #j\"#22c55e\")
    (setf (jscl::oget *ctx* \"font\") #j\"bold 18px monospace\")
    (setf (jscl::oget *ctx* \"textAlign\") #j\"center\")
    ((jscl::oget *ctx* \"fillText\") #j\"λ\" (+ sx 10) (+ sy 18))))

(defun draw-minimap ()
  (let* ((s 2) (mx (- *W* (* *mw* s) 10)) (my 10))
    (setf (jscl::oget *ctx* \"fillStyle\") #j\"rgba(0,0,0,0.6)\")
    ((jscl::oget *ctx* \"fillRect\") (- mx 2) (- my 2) (+ (* *mw* s) 4) (+ (* *mh* s) 4))
    (dotimes (y *mh*)
      (dotimes (x *mw*)
        (let ((tv (tile x y)))
          (when (> tv 0)
            (setf (jscl::oget *ctx* \"fillStyle\")
                  (if (= tv 3) #j\"#fbbf24\" #j\"#1e293b\"))
            ((jscl::oget *ctx* \"fillRect\") (+ mx (* x s)) (+ my (* y s)) s s)))))
    (dolist (e *enemies*)
      (setf (jscl::oget *ctx* \"fillStyle\") #j\"#ef4444\")
      ((jscl::oget *ctx* \"fillRect\") (+ mx (* (getf e :x) s)) (+ my (* (getf e :y) s)) s s))
    (setf (jscl::oget *ctx* \"fillStyle\") #j\"#22c55e\")
    ((jscl::oget *ctx* \"fillRect\") (+ mx (* (getf *player* :x) s)) (+ my (* (getf *player* :y) s)) s s)))

(defun draw-hud ()
  (setf (jscl::oget *ctx* \"fillStyle\") #j\"#0a0a0a\")
  ((jscl::oget *ctx* \"fillRect\") 0 (- *H* 30) *W* 30)
  (setf (jscl::oget *ctx* \"font\") #j\"12px monospace\")
  ;; HP
  (setf (jscl::oget *ctx* \"fillStyle\")
        (if (<= (getf *player* :hp) 3) #j\"#ef4444\" #j\"#22c55e\"))
  (setf (jscl::oget *ctx* \"textAlign\") #j\"left\")
  ((jscl::oget *ctx* \"fillText\")
   (jscl/ffi:jsstring (format nil \"HP: ~a/~a\" (getf *player* :hp) (getf *player* :max-hp)))
   10 (- *H* 12))
  ;; DMG + Lvl + Floor
  (setf (jscl::oget *ctx* \"fillStyle\") #j\"#888\")
  ((jscl::oget *ctx* \"fillText\")
   (jscl/ffi:jsstring (format nil \"DMG:~a Lv:~a Fl:~a\"
                              (getf *player* :dmg) (getf *player* :level) *floor*))
   110 (- *H* 12))
  ;; Score
  (setf (jscl::oget *ctx* \"fillStyle\") #j\"#eab308\")
  (setf (jscl::oget *ctx* \"textAlign\") #j\"right\")
  ((jscl::oget *ctx* \"fillText\")
   (jscl/ffi:jsstring (format nil \"Score:~a\" *score*))
   (- *W* 110) (- *H* 12))
  ;; Best
  (setf (jscl::oget *ctx* \"fillStyle\") #j\"#555\")
  ((jscl::oget *ctx* \"fillText\")
   (jscl/ffi:jsstring (format nil \"Best:~a\" *high-score*))
   (- *W* 10) (- *H* 12))
  ;; Сообщения
  (setf (jscl::oget *ctx* \"textAlign\") #j\"left\")
  (let ((my (- *H* 40)))
    (dolist (m *msgs*)
      (setf (jscl::oget *ctx* \"fillStyle\") (jscl/ffi:jsstring (getf m :color)))
      (setf (jscl::oget *ctx* \"font\") #j\"11px monospace\")
      ((jscl::oget *ctx* \"fillText\") (jscl/ffi:jsstring (getf m :text)) 10 my)
      (decf my 14)))
  ;; Paused
  (when nil ;; *paused* — нет паузы в this roguelike
    nil)
  ;; Game over
  (when *game-over*
    (setf (jscl::oget *ctx* \"fillStyle\") #j\"rgba(0,0,0,0.7)\")
    ((jscl::oget *ctx* \"fillRect\") 0 0 *W* *H*)
    (setf (jscl::oget *ctx* \"fillStyle\") #j\"#ef4444\")
    (setf (jscl::oget *ctx* \"font\") #j\"bold 28px monospace\")
    (setf (jscl::oget *ctx* \"textAlign\") #j\"center\")
    ((jscl::oget *ctx* \"fillText\") #j\"GAME OVER\" (/ *W* 2) (- (/ *H* 2) 10))
    (setf (jscl::oget *ctx* \"fillStyle\") #j\"#fff\")
    (setf (jscl::oget *ctx* \"font\") #j\"16px monospace\")
    ((jscl::oget *ctx* \"fillText\")
     (jscl/ffi:jsstring (format nil \"Score: ~a  Floor: ~a\" *score* *floor*))
     (/ *W* 2) (+ (/ *H* 2) 20))
    (setf (jscl::oget *ctx* \"fillStyle\") #j\"#888\")
    (setf (jscl::oget *ctx* \"font\") #j\"14px monospace\")
    ((jscl::oget *ctx* \"fillText\") #j\"Press Enter\" (/ *W* 2) (+ (/ *H* 2) 50))))

;;; Игровой цикл
(defun game-loop-raw ()
  (read-input)
  (cond
   (*game-over*
    (when (key-just-pressed 13) (reset-game)))
   (t (process-action)))
  ;; Рендер
  (setf (jscl::oget *ctx* \"fillStyle\") #j\"#0a0a0a\")
  ((jscl::oget *ctx* \"fillRect\") 0 0 *W* *H*)
  (draw-tiles)
  (draw-items)
  (draw-enemies)
  (draw-player)
  (draw-minimap)
  (draw-hud)
  (save-key-state))

;;; Точка входа
(defun start-s-dungeon ()
  (ensure-audio-ctx)
  (setf *ctx* ((jscl::oget (#j:document:getElementById #j\"game-canvas\") \"getContext\") #j\"2d\"))
  (let ((doc #j:document))
    ((jscl::oget doc \"addEventListener\")
     #j\"keydown\"
     (lambda (e)
       (let ((code (jscl::oget e \"keyCode\")))
         (setf (aref *keys* code) 1)
         (when (or (= code 37) (= code 38) (= code 39) (= code 40) (= code 32))
           ((jscl::oget e \"preventDefault\"))))))
    ((jscl::oget doc \"addEventListener\")
     #j\"keyup\"
     (lambda (e)
       (setf (aref *keys* (jscl::oget e \"keyCode\")) 0))))
  (reset-game))
")
    ))

(defun get-game-source (name)
  "Возвращает (lang . source) игры по имени."
  (let ((g (assoc name *game-sources* :test #'string=)))
    (when g (cons (second g) (third g)))))
