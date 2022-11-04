;; This mode has two purposes:
;; * display the stack trace that caused the error
;; * allow the user to decide whether to retry after reloading or quit

;; Since we can't know which module needs to be reloaded, we rely on the user
;; doing a ,reload foo in the repl.

(var state nil)

(local explanation "Press escape to quit.
Press space to return to the previous mode after reloading in the repl.")

(fn draw []
  (love.graphics.clear 0.34 0.61 0.86)
  (love.graphics.setColor 0.9 0.9 0.9)
  (love.graphics.print state.msg 10 10)
  (love.graphics.print explanation 15 25)
  (love.graphics.print state.traceback 15 50))

(fn keypressed [key set-mode]
  (match key
    :escape (love.event.quit)
    :space (set-mode state.old-mode)))

(fn activate [old-mode msg traceback]
  (print msg)
  (print traceback)
  (set state {: old-mode : msg : traceback}))

{: draw : keypressed : activate}
