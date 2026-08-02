;;; 20-editing.el --- editor-wide behavior and keys  -*- lexical-binding: t; -*-

(desktop-save-mode 1)

;; Undo/redo window layouts: C-c <left> / C-c <right>.
(winner-mode 1)

(setq-default show-trailing-whitespace t)

(global-set-key [(meta +)] 'align-regexp)
