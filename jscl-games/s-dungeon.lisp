;;; S-Expression Dungeon — roguelike для JSCL
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
  (let* ((o ((jscl::oget *ac* "createOscillator")))
         (g ((jscl::oget *ac* "createGain")))
         (f (jscl::oget o "frequency"))
         (vg (jscl::oget g "gain"))
         (n (jscl::oget *ac* "currentTime")))
    (setf (jscl::oget o "type") wave)
    ((jscl::oget f "setValueAtTime") fe n)
    ((jscl::oget f "exponentialRampToValueAtTime") te (+ n dur))
    ((jscl::oget vg "setValueAtTime") vol n)
    ((jscl::oget vg "exponentialRampToValueAtTime") 0.001 (+ n dur))
    ((jscl::oget o "connect") g)
    ((jscl::oget g "connect") (jscl::oget *ac* "destination"))
    ((jscl::oget o "start") n)
    ((jscl::oget o "stop") (+ n dur))))

(defun snd-step () (play-snd #j"triangle" 200 100 0.04 0.04))
(defun snd-hit () (play-snd #j"sawtooth" 300 100 0.12 0.12))
(defun snd-hurt () (play-snd #j"square" 200 50 0.15 0.15))
(defun snd-pickup () (play-snd #j"sine" 600 1200 0.1 0.1))
(defun snd-stairs () (play-snd #j"sine" 400 800 0.12 0.3))
(defun snd-kill () (play-snd #j"sawtooth" 400 200 0.1 0.2))
(defun snd-die () (play-snd #j"square" 300 50 0.2 0.5))
(defun snd-levelup () (play-snd #j"sine" 400 800 0.1 0.3))

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
  (let ((types (list (list :name "void-fn" :hp 3 :dmg 1 :xp 10 :sym "V" :col "#ef4444")
                     (list :name "wrong-type" :hp 4 :dmg 2 :xp 15 :sym "W" :col "#f97316")
                     (list :name "unbound" :hp 2 :dmg 1 :xp 8 :sym "U" :col "#eab308")
                     (list :name "overflow" :hp 6 :dmg 3 :xp 25 :sym "O" :col "#dc2626")
                     (list :name "null-ref" :hp 3 :dmg 2 :xp 12 :sym "N" :col "#a855f7"))))
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
  (let ((types (list (list :name "defun" :kind :heal :val 3 :col "#22c55e" :sym "λ")
                     (list :name "defmacro" :kind :maxhp :val 1 :col "#3b82f6" :sym "M")
                     (list :name "setf" :kind :dmg :val 1 :col "#a855f7" :sym "=")
                     (list :name "progn" :kind :heal :val 6 :col "#10b981" :sym "+"))))
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
  (add-msg (format nil "Floor ~a. Find >" *floor*) "#888"))

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
        (add-msg (format nil "Hit ~a (-~a)" (getf en :name) d) "#fff")
        (when (<= (getf en :hp) 0)
          (snd-kill)
          (add-msg (format nil "Destroyed ~a!" (getf en :name)) "#22c55e")
          (incf *score* (getf en :xp))
          (incf (getf *player* :xp) (getf en :xp))
          (setf *enemies* (remove en *enemies*))
          (when (>= (getf *player* :xp) (* (getf *player* :level) 20))
            (incf (getf *player* :level))
            (incf (getf *player* :max-hp) 2)
            (incf (getf *player* :hp) 2)
            (incf (getf *player* :dmg))
            (snd-levelup)
            (add-msg (format nil "Level ~a!" (getf *player* :level)) "#eab308")))))
     ;; Стена
     ((= (tile nx ny) 0) nil)
     ;; Лестница
     ((= (tile nx ny) 3)
      (incf *floor*)
      (snd-stairs)
      (add-msg (format nil "Floor ~a..." *floor*) "#3b82f6")
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
           (add-msg (format nil "+~a HP" (getf it :val)) "#22c55e"))
          (:maxhp
           (incf (getf *player* :max-hp) (getf it :val))
           (incf (getf *player* :hp) (getf it :val))
           (add-msg (format nil "+~a max HP" (getf it :val)) "#3b82f6"))
          (:dmg
           (incf (getf *player* :dmg) (getf it :val))
           (add-msg (format nil "+~a dmg" (getf it :val)) "#a855f7")))
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
            (add-msg (format nil "~a -~a HP" (getf e :name) (getf e :dmg)) "#ef4444")
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
             (setf (jscl::oget *ctx* "fillStyle") #j"#111520")
             ((jscl::oget *ctx* "fillRect") sx sy *tile* *tile*)
             (setf (jscl::oget *ctx* "fillStyle") #j"#1e2233")
             ((jscl::oget *ctx* "fillRect") sx sy *tile* 1)
             ((jscl::oget *ctx* "fillRect") sx sy 1 *tile*))
            (1
             (setf (jscl::oget *ctx* "fillStyle") #j"#0d1117")
             ((jscl::oget *ctx* "fillRect") sx sy *tile* *tile*))
            (3
             (setf (jscl::oget *ctx* "fillStyle") #j"#0d1117")
             ((jscl::oget *ctx* "fillRect") sx sy *tile* *tile*)
             (setf (jscl::oget *ctx* "fillStyle") #j"#fbbf24")
             (setf (jscl::oget *ctx* "font") #j"bold 16px monospace")
             (setf (jscl::oget *ctx* "textAlign") #j"center")
             ((jscl::oget *ctx* "fillText") #j">" (+ sx 10) (+ sy 16)))))))))

(defun draw-items ()
  (dolist (it *items*)
    (let ((sx (map-to-sx (getf it :x))) (sy (map-to-sy (getf it :y))))
      (setf (jscl::oget *ctx* "fillStyle") (jscl/ffi:jsstring (getf it :col)))
      (setf (jscl::oget *ctx* "font") #j"bold 14px monospace")
      (setf (jscl::oget *ctx* "textAlign") #j"center")
      ((jscl::oget *ctx* "fillText") (jscl/ffi:jsstring (getf it :sym)) (+ sx 10) (+ sy 16)))))

(defun draw-enemies ()
  (dolist (e *enemies*)
    (let ((sx (map-to-sx (getf e :x))) (sy (map-to-sy (getf e :y))))
      (setf (jscl::oget *ctx* "fillStyle") (jscl/ffi:jsstring (getf e :col)))
      (setf (jscl::oget *ctx* "font") #j"bold 14px monospace")
      (setf (jscl::oget *ctx* "textAlign") #j"center")
      ((jscl::oget *ctx* "fillText") (jscl/ffi:jsstring (getf e :sym)) (+ sx 10) (+ sy 16)))))

(defun draw-player ()
  (let ((sx (map-to-sx (getf *player* :x))) (sy (map-to-sy (getf *player* :y))))
    (setf (jscl::oget *ctx* "fillStyle") #j"#22c55e")
    (setf (jscl::oget *ctx* "font") #j"bold 18px monospace")
    (setf (jscl::oget *ctx* "textAlign") #j"center")
    ((jscl::oget *ctx* "fillText") #j"λ" (+ sx 10) (+ sy 18))))

(defun draw-minimap ()
  (let* ((s 2) (mx (- *W* (* *mw* s) 10)) (my 10))
    (setf (jscl::oget *ctx* "fillStyle") #j"rgba(0,0,0,0.6)")
    ((jscl::oget *ctx* "fillRect") (- mx 2) (- my 2) (+ (* *mw* s) 4) (+ (* *mh* s) 4))
    (dotimes (y *mh*)
      (dotimes (x *mw*)
        (let ((tv (tile x y)))
          (when (> tv 0)
            (setf (jscl::oget *ctx* "fillStyle")
                  (if (= tv 3) #j"#fbbf24" #j"#1e293b"))
            ((jscl::oget *ctx* "fillRect") (+ mx (* x s)) (+ my (* y s)) s s)))))
    (dolist (e *enemies*)
      (setf (jscl::oget *ctx* "fillStyle") #j"#ef4444")
      ((jscl::oget *ctx* "fillRect") (+ mx (* (getf e :x) s)) (+ my (* (getf e :y) s)) s s))
    (setf (jscl::oget *ctx* "fillStyle") #j"#22c55e")
    ((jscl::oget *ctx* "fillRect") (+ mx (* (getf *player* :x) s)) (+ my (* (getf *player* :y) s)) s s)))

(defun draw-hud ()
  (setf (jscl::oget *ctx* "fillStyle") #j"#0a0a0a")
  ((jscl::oget *ctx* "fillRect") 0 (- *H* 30) *W* 30)
  (setf (jscl::oget *ctx* "font") #j"12px monospace")
  ;; HP
  (setf (jscl::oget *ctx* "fillStyle")
        (if (<= (getf *player* :hp) 3) #j"#ef4444" #j"#22c55e"))
  (setf (jscl::oget *ctx* "textAlign") #j"left")
  ((jscl::oget *ctx* "fillText")
   (jscl/ffi:jsstring (format nil "HP: ~a/~a" (getf *player* :hp) (getf *player* :max-hp)))
   10 (- *H* 12))
  ;; DMG + Lvl + Floor
  (setf (jscl::oget *ctx* "fillStyle") #j"#888")
  ((jscl::oget *ctx* "fillText")
   (jscl/ffi:jsstring (format nil "DMG:~a Lv:~a Fl:~a"
                              (getf *player* :dmg) (getf *player* :level) *floor*))
   110 (- *H* 12))
  ;; Score
  (setf (jscl::oget *ctx* "fillStyle") #j"#eab308")
  (setf (jscl::oget *ctx* "textAlign") #j"right")
  ((jscl::oget *ctx* "fillText")
   (jscl/ffi:jsstring (format nil "Score:~a" *score*))
   (- *W* 110) (- *H* 12))
  ;; Best
  (setf (jscl::oget *ctx* "fillStyle") #j"#555")
  ((jscl::oget *ctx* "fillText")
   (jscl/ffi:jsstring (format nil "Best:~a" *high-score*))
   (- *W* 10) (- *H* 12))
  ;; Сообщения
  (setf (jscl::oget *ctx* "textAlign") #j"left")
  (let ((my (- *H* 40)))
    (dolist (m *msgs*)
      (setf (jscl::oget *ctx* "fillStyle") (jscl/ffi:jsstring (getf m :color)))
      (setf (jscl::oget *ctx* "font") #j"11px monospace")
      ((jscl::oget *ctx* "fillText") (jscl/ffi:jsstring (getf m :text)) 10 my)
      (decf my 14)))
  ;; Paused
  (when nil ;; *paused* — нет паузы в this roguelike
    nil)
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
    ((jscl::oget *ctx* "fillText")
     (jscl/ffi:jsstring (format nil "Score: ~a  Floor: ~a" *score* *floor*))
     (/ *W* 2) (+ (/ *H* 2) 20))
    (setf (jscl::oget *ctx* "fillStyle") #j"#888")
    (setf (jscl::oget *ctx* "font") #j"14px monospace")
    ((jscl::oget *ctx* "fillText") #j"Press Enter" (/ *W* 2) (+ (/ *H* 2) 50))))

;;; Игровой цикл
(defun game-loop-raw ()
  (read-input)
  (cond
   (*game-over*
    (when (key-just-pressed 13) (reset-game)))
   (t (process-action)))
  ;; Рендер
  (setf (jscl::oget *ctx* "fillStyle") #j"#0a0a0a")
  ((jscl::oget *ctx* "fillRect") 0 0 *W* *H*)
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
  (reset-game))
