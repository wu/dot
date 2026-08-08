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
