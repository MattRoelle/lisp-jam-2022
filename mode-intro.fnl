(import-macros {: incf} :sample-macros)
(local lume (require :lib.lume))

(love.graphics.setDefaultFilter :nearest :nearest)

;; Constants 
(local stage-width (/ 1920 2))
(local stage-height (/ 1080 2))
(local stage-center-x (/ stage-width 2))
(local stage-center-y (/ stage-height 2))
(local space-size 32)
(local board-y stage-center-y)
(local exp-curve [8 13 21 34 55 89])


;; Assets 
(local fnt12 (love.graphics.newFont :assets/04B_30__.ttf 12))
(local fnt16 (love.graphics.newFont :assets/04B_30__.ttf 16))
(local fnt24 (love.graphics.newFont :assets/04B_30__.ttf 24))
(local fnt32 (love.graphics.newFont :assets/04B_30__.ttf 32))

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
(var player-state 
  {:n 1
   :hp 70 
   :max-hp 70 
   :exp 0
   :str 6
   :light 5
   :effects []
   :inventory []
   :gold 50})

(var actions 
  [{:label "BACK" :handler #(set player-state.n (math.max 1 (- player-state.n 1)))}
   {:label "THROW" :handler #(set player-state.n (+ player-state.n 1))}
   {:label "ITEM" :handler #(set player-state.n (+ player-state.n 1))}
   {:label "FORWARD" :handler #(set player-state.n (+ player-state.n 1))}])

;; Game Logic 
(λ log [s]
  (table.insert logs 1 s))

(λ get-level []
  (accumulate [acc 1 ix thresh (ipairs exp-curve)]
    (if (> player-state.exp thresh)
      (+ acc 1)
      acc)))

(λ generate-board []
  (set board [])
  (for [i 1 100]
    (table.insert board {:type :empty})))

(λ submit-action [n]
  (let [action (. actions n)]
    (when action 
      (log action.label)
      (print :doing-action action.label)
      ((. action :handler)))))

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

(λ draw-progress-bar [color x y w h v max]
  (with-transform (- x (/ w 2))
                  (- y (/ h 2))
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
  (draw-rectangle palette.black -8 -24 24 36 5)
  (draw-rectangle palette.white -8 -24 20 32 4)
  (love.graphics.setColor (unpack palette.white))
  (draw-text 5 fnt32 palette.red -8 -120))
  ; (draw-progress-bar palette.red -8 -44 24 8 player-state.hp player-state.max-hp))

(λ draw-board []
  (for [i (* -1 player-state.light) player-state.light]
    (let [space-n (+ player-state.n i)
          space (. board space-n)
          x (animate (.. :board-space- space-n) i (* DT 3) {:start 
                                                            (if (<= space-n 6) nil
                                                              (+ i (if (> i 0) 1 -1)))})]
      (when space
        (with-transform (+ stage-center-x (* x space-size 1.25)) (* stage-height 0.66) 0 1 1
           (draw-board-space 0 0 palette.fg 
                             (animate (.. :board-space- space-n :-lum)
                                      (if (= player-state.n space-n) 1 
                                          (= (math.abs i) player-state.light) 0.35
                                        0.6)
                                      (* DT 6)
                                      {:start 0}))))))
  (with-transform (+ stage-center-x 0) (* stage-height 0.66) 0 1 1
    (draw-player)))

(λ draw-stat-box [color x y label value]
  (with-transform x y 0 1 1
    ; (love.graphics.setColor 0.2 0.2 0.2 1)
    ; (love.graphics.rectangle :fill -2 2 200 32)
    (love.graphics.setColor (unpack color))
    (love.graphics.rectangle :fill 0 0 200 32 8)
    (love.graphics.setFont fnt24)
    (love.graphics.setColor 0 0 0 1)
    (love.graphics.print (.. label " " value) 8 4)))

(λ draw-ui []
  (draw-stat-box palette.fg 16 16 "HP" player-state.hp)
  (draw-stat-box palette.fg 16 52 "LVL" (get-level))
  (draw-stat-box palette.fg 16 88 "STR" player-state.str)
  (for [i 1 10]
    (when (. logs i)
      (love.graphics.setFont fnt12)
      (love.graphics.setColor (unpack palette.white))
      (love.graphics.print (. logs i)  (* stage-width 0.75) (+ 20 (* 14 (- i 1)))))))
  ; (draw-stat-box palette.fg 5 32 "LVL" (get-level player-state.exp)))

(λ draw-actions []
  (let [total-button-width (/ stage-width 4)
        button-width (* total-button-width 0.9)
        margin (- total-button-width button-width)
        half-margin (/ margin 2)]
    (for [i 1 4]
      (let [action (. actions i)]
        (when action
         (with-transform (+ half-margin (* (- i 1) (+ button-width margin))) 
                       (* stage-height 0.77)
                       0 1 1
          (love.graphics.setColor (unpack palette.fg))
          (love.graphics.rectangle :fill 0 0 button-width 100 4)
          (love.graphics.setFont fnt24)
          (love.graphics.setColor 0 0 0 1)
          (love.graphics.print (tostring i) 4 4)
          (love.graphics.print (. action :label) 4 72)))))))
       ; (love.graphics.setFont fnt24)
       ; (love.graphics.setColor 0 0 0 1)
       ; (love.graphics.print "HP 100" 4 4)))))

;; Main 
(generate-board)

{:draw (λ draw [?message]
         (local (w h _flags) (love.window.getMode))
         (draw-rectangle palette.bg 0 0 w h 10)
         (draw-board)
         (draw-actions)
         (draw-ui))

 :update (λ update [dt set-mode]
           (print T)
           (set DT dt)
           (set T (+ T DT))
           (clean-stale-animations!))
 :keypressed 
 (λ keypressed [key set-mode]
   (if (= key :1) (submit-action 1)
       (= key :2) (submit-action 2)
       (= key :3) (submit-action 3)
       (= key :4) (submit-action 4)))}

