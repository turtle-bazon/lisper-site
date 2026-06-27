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

;;; Ввод
(defvar *keys* (make-array 256 :initial-element 0))
(defvar *prev-space* nil)
(defvar *pause-clicks* 0)
(defvar *reset-clicks* 0)
(defvar *prev-p* nil)
(defvar *prev-enter* nil)

(defun key-pressed (code)
  (= 1 (aref *keys* code)))

(defun read-input ()
  (let ((space-now (key-pressed 32)))
    (when (and space-now (not *prev-space*) (not *jumping*) (not *game-over*))
      (setf *jumping* t *jump-vy* *jump-force*))
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
  (setf *score* 0 *speed* 3.0 *tick* 0
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
  (incf *speed* 0.0005)

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
  (when (and *game-over* (not (zerop *score*))) (snd-hit))
  (when (> *score* (+ *prev-score* 50)) (snd-collect)))

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
    ))

(defun get-game-source (name)
  "Возвращает (lang . source) игры по имени."
  (let ((g (assoc name *game-sources* :test #'string=)))
    (when g (cons (second g) (third g)))))
