;;; 27-frames.el --- moving between windows and frames  -*- lexical-binding: t; -*-

;; S-<arrow> selects the window in that direction, instead of cycling through
;; every window with C-x o to reach the one already on screen.
;;
;; This costs shift-selection of a region with the arrow keys; pass a modifier
;; -- (windmove-default-keybindings 'meta) -- to keep it.  C-c <arrow> is not
;; free either, `tab-bar-history-mode' has it (20-editing.el).
;;
;; Confined to the selected frame: `windmove' resolves direction through
;; `window-in-direction', which does not look at other frames.
(windmove-default-keybindings)

;; S-M-<arrow> swaps this window's buffer with the one in that direction, and
;; carries point along with it.
;;
;; The modifiers are passed explicitly: this function's default is not the
;; plain shift used above, so calling it bare leaves S-M-<arrow> unbound --
;; which looks like nothing happening, since Emacs then falls back to the
;; unshifted M-<arrow> and reports *that* as undefined.
;;
;; org-mode claims S-M-<arrow> for `org-shiftmeta*' (promote/demote, move
;; subtree), so the swap will not reach a window from inside an org buffer.
(windmove-swap-states-default-keybindings '(shift meta))

;; Turn a side-by-side split into a stacked one and back.
;;
;; Emacs 31 has this built in as `window-layout-transpose' on C-x w t, along
;; with the flip and rotate commands on C-x w f/r/o -- and it handles any
;; layout, not just two windows.  Define the fallback only below 31, and put it
;; on the same key, so upgrading swaps in the better command silently.
;;
;; Note that hi-lock claims the C-x w prefix for its highlight commands once it
;; is loaded; C-x w t is free within it, but C-h k here if a conflict shows up.
(unless (fboundp 'window-layout-transpose)
  (defun toggle-window-split ()
    "Swap a horizontal split of two windows for a vertical one, or back."
    (interactive)
    (unless (= (count-windows) 2)
      (user-error "Works only on exactly two windows"))
    (let* ((this-win-buffer (window-buffer))
           (next-win-buffer (window-buffer (next-window)))
           (this-win-edges (window-edges (selected-window)))
           (next-win-edges (window-edges (next-window)))
           ;; Which of the two is on the left/top decides where the buffers land
           ;; after the re-split.
           (this-win-2nd (not (and (<= (car this-win-edges) (car next-win-edges))
                                   (<= (cadr this-win-edges) (cadr next-win-edges)))))
           ;; Equal left edges mean the split is horizontal, so re-split the
           ;; other way.
           (splitter (if (= (car this-win-edges) (car next-win-edges))
                         'split-window-horizontally
                       'split-window-vertically)))
      (delete-other-windows)
      (let ((first-win (selected-window)))
        (funcall splitter)
        (when this-win-2nd (other-window 1))
        (set-window-buffer (selected-window) this-win-buffer)
        (set-window-buffer (next-window) next-win-buffer)
        (select-window first-win)
        (when this-win-2nd (other-window 1)))))

  (keymap-global-set "C-x w t" #'toggle-window-split))
