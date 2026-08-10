;;; 27-frames.el --- moving between windows and frames  -*- lexical-binding: t; -*-

;; S-<arrow> selects the window in that direction, instead of cycling through
;; every window with C-x o to reach the one already on screen.
;;
;; This costs shift-selection of a region with the arrow keys; pass a modifier
;; -- (windmove-default-keybindings 'meta) -- to keep it.  C-c <arrow> is not
;; free either, winner-mode has it (20-editing.el).
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
