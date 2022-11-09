(import-macros {: incf} :sample-macros)
(local lume (require :lib.lume))


;; Constants 
(local stage-width (/ 1920 2))
(local stage-height (/ 1080 2))
(local stage-center-x (/ stage-width 2))
(local stage-center-y (/ stage-height 2))
(local space-size 32)
(local board-y stage-center-y)
(local exp-curve [8 13 21 34 55 89])

;; Assets 
(love.graphics.setDefaultFilter :nearest :nearest)
(λ load-fnt [path sz]
  (let [fnt (love.graphics.newFont path sz)]
    (fnt:setFilter :nearest :nearest)
    fnt))
(local font-xs (load-fnt :assets/upheavtt.ttf 16))
(local fnt-sm (load-fnt :assets/upheavtt.ttf 20))
(local fnt-md (load-fnt :assets/upheavtt.ttf 28))
(local fnt-lg (load-fnt :assets/upheavtt.ttf 36))

;; Palettes 
(local palettes 
  {:default 
   {:bg [0.05 0.05 0.05 1]
    :fg [0.38 0.68 0.90 1]
    :red [1 0 0 1]
    :white [1 1 1 1]
    :black [0 0 0 1]}
   :inverse 
   {:fg [0.05 0.05 0.05 1]
    :bg [0.38 0.68 0.90 1]
    :black [1 1 1 1]
    :white [0 0 0 1]}})

;; Global variables
(var DT 0)
(var T 0)
(var palette palettes.default)
(var board [])
(var logs [])
(var last-keydown nil)

(var shake-until -1)
(var shake-intensity 0)
(λ screen-shake [duration intensity]
  (set shake-until (+ T duration))
  (set shake-intensity intensity))


(var player-state 
  {:n 1
   :hp 70 
   :max-hp 70 
   :exp 0
   :str 6
   :light 6
   :weapon {:name :dagger :attack 5}
   :effects []
   :inventory []
   :gold 50})
(var inventory-open false)
(var actions [])

;; Game Logic 
(λ log [s]
  (table.insert logs 1 (string.upper s)))

(λ get-level []
  (accumulate [acc 1 ix thresh (ipairs exp-curve)]
    (if (> player-state.exp thresh)
      (+ acc 1)
      acc)))

(λ generate-board []
  (set board [])
  (for [i 1 100]
    (table.insert board {:type :empty 
                         :enemy (if 
                                  (= 5 i) {:type :bat :hp 5}
                                  (= 0 (% i 10)) {:type :bat :hp 5}
                                  nil)})))

(λ open-inventory []
  (set inventory-open (not inventory-open)))

(λ move-backwards []
  (when (> player-state.n 1)
    (set player-state.n (- player-state.n 1))))

(λ get-attack []
  (or (?. player-state.weapon :attack) 1))

(λ player-hurt [v]
  (set player-state.hp (- player-state.hp v)))

(λ get-enemy-attack [enmy]
  2)

(λ get-enemy-hit-chance [enmy]
  (> (math.random) 0.5))

(λ fight []
  (screen-shake 0.3 4)
  (let [enmy (assert (. board (+ player-state.n 1) :enemy))
        atk (get-attack)]
    (set enmy.hp (- enmy.hp atk))
    (when (get-enemy-hit-chance enmy)
      (log (.. "The " enmy.type " attacks you for " (.. (get-enemy-attack enmy))))
      (player-hurt (get-enemy-attack enmy)))
    (when (< enmy.hp 1)
      (log (.. "The " enmy.type " dies"))
      (tset board (+ player-state.n 1) :enemy nil))))


(λ move-forward []
  (if (= player-state.n 1) (log "You take your first steps"))
  (let [next-tile (. board (+ player-state.n 1))]
    (if next-tile.enemy
      (fight)
      (set player-state.n (+ player-state.n 1)))))


(λ determine-next-action []
  (let [tile (. board player-state.n)
        next-tile (. board (+ player-state.n 1))
        weapon-name (or (?. player-state.weapon :name) :fists)
        weapon-atk (or (?. player-state.weapon :attack) 1)]
     [{:label "FORWARD" :keys ["right" "l"] :handler move-forward}
      {:label "BACKWARDS" :keys ["left" "h"] :handler move-backwards}
      {:label "INVENTORY" :keys ["i"]  :handler open-inventory}]))

(λ match-kbd-to-action [key]
  (var ret nil)
  (each [ix v (ipairs actions)]
    (when (lume.find v.keys key)
      (set ret v)))
  ret)
  

(λ handle-key-action [key]
  (let [action (match-kbd-to-action key)]
    (when (?. action :handler) 
      ((. action :handler))
      (set actions (determine-next-action)))))

;; Macros
(macro with-transform [x y angle sx sy ...]
 `(do
   (love.graphics.push)
   (love.graphics.translate ,x ,y)
   (love.graphics.rotate ,angle)
   (love.graphics.scale ,sx ,sy)
   (do ,...)
   (love.graphics.pop)))

;; Animation helpers
(var anim-state {})
(λ animate [key val t ?options]
  (let [opts (lume.merge 
               {} 
               (or ?options {}))]
    (when (not (. anim-state key))
      (tset anim-state key {:v (or opts.start val)}))
    (let [anim (. anim-state key)]
      (set anim.v (lume.lerp anim.v val t))
      (set anim.last T)
      anim.v)))

(λ clean-stale-animations! []
  (set anim-state 
       (collect [k v (pairs anim-state)]
         (let [delta (- T v.last)]
           (when (< delta 0.1)
             (values k v))))))

;; Drawing functions
(λ set-alpha [c a]
  (let [[r g b] c]
    [r g b a]))

(λ *color [color v]
  (icollect [_ c (ipairs color)]
    (* v c)))

(λ draw-text [s fnt color x y]
  (love.graphics.setColor (unpack color))
  (love.graphics.print s fnt x y))

(λ draw-rectangle [color x y w h ?r]
  (with-transform (- x (/ w 2))
                  (- y (/ h 2))
                  0 1 1
    (love.graphics.setColor (unpack color))
    (love.graphics.rectangle :fill x y w h ?r)))

(λ stroke-rectangle [color x y w h ?r ?w]
  (with-transform (- x (/ w 2))
                  (- y (/ h 2))
                  0 1 1
    (love.graphics.setColor (unpack color))
    (love.graphics.setLineWidth (or ?w 1))
    (love.graphics.rectangle :line x y w h ?r)))

(λ draw-progress-bar [color x y w h v max]
  (with-transform (- x (/ w 4))
                  (- y (/ h 4))
                  0 1 1
    (love.graphics.setColor (unpack color))
    (love.graphics.rectangle :fill x y (* w (/ v max)) h)))

(λ draw-board-space [x y color lum]
  (with-transform (- x (/ space-size 2)) 
                  (- y space-size) 
                  0 1 1
    (draw-rectangle (*color palette.white lum) 0 0 (* 1.05 space-size) (* 1.05 space-size) 10)
    (draw-rectangle palette.bg 0 0 space-size space-size 10)
    (draw-rectangle (*color color lum) 0 0 (* 0.8 space-size) (* 0.8 space-size) 10)))

(λ draw-player []
  (let [h (+ 0.9 (* 0.1 (math.sin (* 2 T))))]
     (draw-rectangle palette.black -8 -24 24 (* h 36) 5)
     (draw-rectangle palette.white -8 -24 20 (* h 32) 4))
  (love.graphics.setColor (unpack palette.white)))
  ; (draw-text 5 fnt-lg palette.red -8 -120))
  ; (draw-progress-bar palette.red -8 -44 24 8 player-state.hp player-state.max-hp))

(λ draw-enemy [enemy]
  ;; Kind of a hack to put this here?
  (when (not enemy.shown)
    (set enemy.shown true)
    (log (.. "There is a " enemy.type)))
  (draw-text enemy.hp fnt-md palette.red -25 -8) 
  (draw-rectangle palette.red -8 (+ (* 4 (math.sin (* 2 T))) -32) 16 16 2))

(λ draw-board []
  (for [i (* -1 player-state.light) player-state.light]
    (let [space-n (+ player-state.n i)
          space (. board space-n)
          x (animate (.. :board-space- space-n) i (* DT 6) 
                     {:start (if (<= space-n 6) nil
                               (+ i (if (> i 0) 1 -1)))})]
      (when space
        (with-transform (+ stage-center-x (* x space-size 1.25)) 
                        (* stage-height 0.66) 
                        0 1 1
           (draw-board-space 0 0 palette.fg 
                             (animate (.. :board-space- space-n :-lum)
                                      (if (= player-state.n space-n) 1 
                                          (= (math.abs i) player-state.light) 0.35
                                        0.6)
                                      (* DT 6)
                                      {:start 0}))
           (when space.enemy
             (draw-enemy space.enemy))))))
  (with-transform (+ stage-center-x 0) (* stage-height 0.66) 0 1 1
    (draw-player)))

(λ draw-stat-box [color x y label value]
  (with-transform x y 0 1 1
    ; (love.graphics.setColor 0.2 0.2 0.2 1)
    ; (love.graphics.rectangle :fill -2 2 200 32)
    (love.graphics.setColor (unpack color))
    (love.graphics.rectangle :fill 0 0 200 32 8)
    (love.graphics.setFont fnt-md)
    (love.graphics.setColor 0 0 0 1)
    (love.graphics.print (.. label " " value) 8 4)))

(λ draw-modal [key title draw-body]
 (let [t (animate key 1 (* DT 16) {:start 0})
       w 440
       h (* w (/ 2 3)) 
       bw 8
       top-x stage-center-x
       top-y (- stage-center-y (* h 0.35) (* (- 1 t) -32))]
    (with-transform top-x top-y 0 1 1
      (stroke-rectangle (set-alpha palette.fg 1) 0 0 w h 4 bw)
      (draw-rectangle (set-alpha palette.black 1) 0 0 w h 4)
      (love.graphics.translate (+ bw (* w -0.5)) (* h -0.5))
      (draw-text title fnt-lg palette.white 0 0)
      (draw-body t))))
          

(λ draw-inventory []
  (draw-modal :inventory "INVENTORY"
    #(do))) 
       ; (draw-rectangle palette.fg 0 0 40 40))))

(λ draw-ui []
  (draw-stat-box palette.fg 16 16 "HP" player-state.hp)
  (draw-stat-box palette.fg 16 52 "LVL" (get-level))
  (draw-stat-box palette.fg 16 88 "STR" player-state.str)
  (draw-text player-state.n fnt-sm palette.white (- stage-width 64) 4)
  (for [i 1 10]
    (let [j (- 10 i)]
      (when (. logs i)
       (love.graphics.setFont font-xs)
       (love.graphics.setColor (*color palette.white (math.max 0.1 (/ j 5))))
       (love.graphics.print (. logs i)  (* stage-width 0.333) (+ 20 (* 14 (- j 1)))))))
  (when inventory-open 
    (draw-inventory)))
  ; (draw-stat-box palette.fg 5 32 "LVL" (get-level player-state.exp)))

(λ draw-actions []
  (let [total-button-width (/ stage-width 4)
        button-width (* total-button-width 0.9)
        active-action (if last-keydown (match-kbd-to-action last-keydown) nil)
        margin (- total-button-width button-width)
        half-margin (/ margin 2)]
    (each [i action (ipairs actions)]
      (with-transform 40 (+ (* i 18) (* stage-height 0.75)) 0 1 1
       (if (= action active-action)
         (do 
           (love.graphics.setColor 0.2 0.2 0.2 1)
           (love.graphics.rectangle :fill -4 0 300 18)
           (draw-text (table.concat action.keys " or ") fnt-sm palette.fg 0 0)
           (draw-text action.label fnt-sm palette.white 150 0))
         (do 
           (draw-text (table.concat action.keys " or ") fnt-sm palette.fg 0 0)
           (draw-text action.label fnt-sm palette.white 150 0)))))))
       ; (love.graphics.setColor (unpack palette.fg))
       ; (love.graphics.rectangle :fill 0 0 button-width 100 4)
       ; (love.graphics.setFont fnt-md)
       ; (love.graphics.setColor 0 0 0 1)
       ; (love.graphics.print (tostring i) 4 4)
       ; (love.graphics.print action.label 4 72)
       ; (when action.text
       ;   (draw-text action.text fnt-md [0 0 0 1] 4 40))))))
       ; (love.graphics.setFont fnt-md)
       ; (love.graphics.setColor 0 0 0 1)
       ; (love.graphics.print "HP 100" 4 4)))))

;; Main 
(generate-board)
(set actions (determine-next-action))
(log "You must get to the end of the cave")

{:draw (λ draw [?message]
         (local (w h _flags) (love.window.getMode))
         (draw-rectangle palette.bg 0 0 w h 10)
         (if (< T shake-until)
           (with-transform (- (* (math.random) shake-intensity 2) shake-intensity)
                           (- (* (math.random) shake-intensity 2) shake-intensity)
                           0 1 1
            (draw-board))
           (draw-board))
         (draw-actions)
         (draw-ui))

 :update (λ update [dt set-mode]
           (set DT dt)
           (set T (+ T DT))
           (clean-stale-animations!))
 :keyreleased 
 (λ keyreleased [key set-mode]
   (set last-keydown nil))
 :keypressed 
 (λ keypressed [key set-mode]
   (set last-keydown key)
   (handle-key-action key))}

